#!/usr/bin/env bash

docker_getImageName() {
    local label="$1"
    echo "$RELEASE_TARGET.$label.$RECIPE_NAME.$APP_NAME"
}

docker_getContainerName() {
    local label="$1"
    echo "$label.$RECIPE_NAME.$APP_NAME"
}

docker_getContIdByName() {
    local contName="$1"
    echo $(docker ps -f "name=$contName" --format '{{.ID}}')
}

docker_buildImage() {
    local context="$1"
    local imageName="$2"
    local dockerfile=${3:-Dockerfile}

    if [[ ! -f $dockerfile ]]; then
        error "dockerfile does not exist, $dockerfile"
    fi

    [[ ! -d ./builds ]] && mkdir ./builds

    local image_tag="$imageName":"latest"
    local image_archive="$imageName".tar

    docker build \
        -f "$dockerfile" \
        -t "$image_tag" \
    "$context"

    docker save -o ./builds/"$image_archive" "$image_tag" >/dev/null
}

docker_reloadImage() {
    local remoteHost="$1"
    local sshKey="$2"
    local imageName="$3"
    local archiveName="$imageName".tar

    local imagesDir='~/docker-images'
    local timestamp=$(date +%Y-%m-%d_%H:%M)

    # Create directory for the image archive if not exists
    ssh -T "$remoteHost" -i "$sshKey"  "mkdir -p $imagesDir"

    # Upload the image archive and load it
    scp -i "$sshKey" "./builds/$archiveName" "$remoteHost":"$imagesDir" && \
    ssh -T "$remoteHost" -i "$sshKey" "docker load -q -i $imagesDir/$archiveName >/dev/null"
}

docker_restartContainer() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local contName=$(docker_getContainerName "$label")

    long_process_start "Restarting Docker container [ $contName ] on the host $remoteHost"
        (
            ssh "$remoteHost" -i "$sshKey" "docker restart $contName"
        ) > /dev/null
    long_process_end
}

docker_startContainer() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        (
            ssh -T "$remoteHost" -i "$sshKey" <<EOF
                cont_id=\$(docker ps -aqf "name=$contName")
                [[ \$cont_id ]] && docker start \$cont_id
EOF
        ) > /dev/null
    long_process_end
}

docker_stopContainer() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local contName=$(docker_getContainerName "$label")

    long_process_start "Stopping Docker container [ $contName ] on the host $remoteHost"
        (
            ssh -T "$remoteHost" -i "$sshKey" <<EOF
                cont_id=\$(docker ps -qf "name=$contName")
                [[ \$cont_id ]] && docker stop \$cont_id
                :
EOF
        ) > /dev/null
    long_process_end
}

docker_stopAndRemoveContainer() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local contName=$(docker_getContainerName "$label")

    long_process_start "Stopping and removing Docker container [ $contName ] on the host $remoteHost"
        (
            ssh -T "$remoteHost" -i "$sshKey" <<EOF
                cont_id=\$(docker ps -aqf "name=$contName")
                [[ ! -z \$cont_id ]] && docker stop \$cont_id && docker rm -f \$cont_id
                :
EOF
        ) > /dev/null
    long_process_end
}

docker_hardRestart() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"

    docker_stopAndRemoveContainer "$remoteHost" "$sshKey" "$label"

    if [[ $imageName = 'redis' ]]; then
        docker_startRedis "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'mongodb' ]]; then
        docker_startMongoDb "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'postgresql' ]]; then
        docker_startPostgreSql "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'nginx' ]]; then
        docker_startNginx "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'nodejs' ]]; then
        docker_startNodejs "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'php-fpm' ]]; then
        docker_startPhpFpm "$remoteHost" "$sshKey" "$label"
    elif [[ $imageName = 'elasticsearch' ]]; then
        docker_startElasticsearch "$remoteHost" "$sshKey" "$label"
    fi
}

docker_syncImage() {
    local remoteHost="$1"
    local sshKey="$2"
    local imageName="$3"

    ( ssh -T "$remoteHost" -i "$sshKey" <<EOF
        mkdir -p /etc/letsencrypt
        mkdir -p $WEB_ROOT
        mkdir -p $DATA_ROOT/app/public
        mkdir -p $DATA_ROOT/redis
        mkdir -p $DATA_ROOT/mongodb

        if ! docker network ls --format {{.Name}} | grep -q $RECIPE_NAME-net; then
            docker network create $RECIPE_NAME-net
        fi
EOF
    ) > /dev/null

    long_process_start "Uploading Docker image [ $imageName ] to the target host $remoteHost"
        docker_reloadImage "$remoteHost" "$sshKey" "$imageName"
    long_process_end
}

docker_build() {
    local release_target="$1"
    local context_dir=${CONTEXT_DIR:-"$DOCKER_DIR/$IMAGE_LABEL/$release_target/."}
    local dockerfile="$DOCKER_DIR/$IMAGE_LABEL/$release_target/Dockerfile"
    local imageName=$(docker_getImageName "$IMAGE_LABEL")

    long_process_start "Building [ $imageName ] image"
        docker_buildImage "$context_dir" \
            "$imageName" \
            "$dockerfile"
    long_process_end
}

docker_startNginx() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ( ssh "$remoteHost" -i "$sshKey" "docker run -d -p 443:443 -p 80:80 --name=$contName \
            -v /etc/letsencrypt:/etc/letsencrypt \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/var/www/html \
            $NGINX_MOUNTS \
            -e CERTBOT_DOMAINS=\"$DOMAIN_NAMES\" \
            -e ADMIN_EMAIL=$ADMIN_EMAIL \
            --network=$RECIPE_NAME-net \
            $imageName:latest"
        ) > /dev/null
    long_process_end
}

docker_startPostgreSql() {
    local remoteHost="$1"
    local sshKey="$2"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ssh -T "$remoteHost" -i "$sshKey" "docker run -d --name=$contName \
            --restart=on-failure:3 \
            --network=$RECIPE_NAME-net \
            -e POSTGRES_DB=$POSTGRES_DB \
            -e POSTGRES_USER=root \
            -e POSTGRES_PASSWORD=root \
            --mount type=bind,source=$DATA_ROOT/shared,target=/shared \
            -v $DATA_ROOT/postgres:/var/lib/postgresql/data \
            $imageName:latest"
    long_process_end
}

docker_startRedis() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ssh "$remoteHost" -i "$sshKey" "docker run -d --name=$contName \
            --restart=on-failure:3 \
            --network=$RECIPE_NAME-net \
            --mount type=bind,source=$DATA_ROOT/redis,target=/data/redis \
            $imageName:latest"
    long_process_end
}

docker_startPhpFpm() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"

        ( ssh "$remoteHost" -i "$sshKey" "docker run -d --name=$contName \
            --mount type=bind,source=/tmp,target=/tmp \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/var/www/html \
            --mount type=bind,source=$DATA_ROOT/shared,target=/shared \
            $PHP_FPM_MOUNTS \
            --network=$RECIPE_NAME-net \
            $imageName:latest"
        ) > /dev/null

    long_process_end
}

docker_startElasticsearch() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ( ssh "$remoteHost" -i "$sshKey" "docker run -d --name=$contName \
            --network=$RECIPE_NAME-net \
            -e ES_JAVA_OPTS='-Xms256m -Xmx640m' \
            $imageName:latest"
        ) > /dev/null
    long_process_end
}

docker_startMongoDb() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ( ssh "$remoteHost" -i "$sshKey" "docker run -d --name=$contName \
            --restart=on-failure:3 \
            --network=$RECIPE_NAME-net \
            --mount type=bind,source=$DATA_ROOT/mongodb,target=/data/mongodb \
            $imageName:latest"
        ) > /dev/null
    long_process_end
}

docker_startNodejs() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"
    local imageName=$(docker_getImageName "$label")
    local contName=$(docker_getContainerName "$label")

    long_process_start "Starting Docker container [ $contName ] on the host $remoteHost"
        ( ssh "$remoteHost" -i "$sshKey" "docker run -d -p 80:80 -p 443:443 --name=$contName \
            -v /etc/letsencrypt:/etc/letsencrypt \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/usr/src/app \
            --restart=on-failure:3 \
            --network=$RECIPE_NAME-net \
            -e CERTBOT_DOMAINS=\"$DOMAINS\" \
            $imageName:latest"
        ) > /dev/null
    long_process_end
}