#!/usr/bin/env bash

docker_getDefaultImageContainerName() {
    echo "$IMAGE_NAME.$RECIPE.$APP_NAME"
}

docker_getContIdByName() {
    local cont_name="$1"

    echo $(docker ps -f "name=$cont_name" --format '{{.ID}}')
}

docker_buildImage() {
    local context="$1"
    local image_name="$2"
    local dockerfile=${3:-Dockerfile}

    if [[ ! -f $dockerfile ]]; then
        error "dockerfile does not exist, $dockerfile"
    fi

    [[ ! -d ./builds ]] && mkdir ./builds

    local image_tag="$image_name":"latest"
    local image_archive="$image_name".tar

    docker build \
        -f "$dockerfile" \
        -t "$image_tag" \
    "$context"

    docker save -o ./builds/"$image_archive" "$image_tag" >/dev/null
}

docker_reloadImage() {
    local remote_host="$1"
    local ssh_key="$2"
    local archive_name="$3".tar

    local remote_images_dir='~/docker-images'
    local timestamp=$(date +%Y-%m-%d_%H:%M)

    # Create directory for the image archive if not exists
    ssh -T "$remote_host" -i "$ssh_key"  "mkdir -p $remote_images_dir"

    # Upload the image archive and load it
    scp -i "$ssh_key" "./builds/$archive_name" "$remote_host":"$remote_images_dir" && \
    ssh -T "$remote_host" -i "$ssh_key" "docker load -q -i $remote_images_dir/$archive_name >/dev/null"
}

docker_restartContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    ssh "$remote_host" -i "$ssh_key" "docker restart -t $DOCKER_RESTART_CONTAINER_TIMEOUT $cont_name"
}

docker_startContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    long_process_start "Starting Docker container [ $cont_name ] on the host $remote_host"
        (
            ssh -T "$remote_host" -i "$ssh_key" <<EOF
                cont_id=\$(docker ps -aqf "name=$cont_name")
                [[ \$cont_id ]] && docker start \$cont_id
EOF
        ) > /dev/null
    long_process_end
}

docker_stopContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    long_process_start "Stopping Docker container [ $cont_name ] on the host $remote_host"
        (
            ssh -T "$remote_host" -i "$ssh_key" <<EOF
                cont_id=\$(docker ps -qf "name=$cont_name")
                [[ \$cont_id ]] && docker stop -t $DOCKER_STOP_CONTAINER_TIMEOUT \$cont_id
                :
EOF
        ) > /dev/null
    long_process_end
}

docker_stopAndRemoveContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    long_process_start "Stopping and removing Docker container [ $cont_name ] on the host $remote_host"
        (
            ssh -T "$remote_host" -i "$ssh_key" <<EOF
                cont_id=\$(docker ps -aqf "name=$cont_name")
                [[ ! -z \$cont_id ]] && docker stop \$cont_id && docker rm -f \$cont_id
                :
EOF
        ) > /dev/null
    long_process_end
}

docker_syncImage() {
    local remote_host="$1"
    local ssh_key="$2"
    local image_name="$3"

    ( ssh -T "$remote_host" -i "$ssh_key" <<EOF
        mkdir -p $WEB_ROOT
        mkdir -p $DATA_ROOT/app/public
        mkdir -p $DATA_ROOT/redis
        mkdir -p $DATA_ROOT/mongodb

        if ! docker network ls --format {{.Name}} | grep -q $RECIPE-net; then
            docker network create $RECIPE-net
        fi
EOF
    ) > /dev/null

    long_process_start "Uploading Docker image [ $image_name ] to the target host $remote_host"
        docker_reloadImage "$remote_host" "$ssh_key" "$image_name"
    long_process_end
}

docker_build() {
    local release_target="$1"
    local context_dir="$DOCKER_DIR/$IMAGE_NAME/$release_target/."
    local dockerfile="$DOCKER_DIR/$IMAGE_NAME/$release_target/Dockerfile"
    local image_name=$(docker_getDefaultImageContainerName)

    long_process_start "Building [ $image_name ] image"
        docker_buildImage "$context_dir" \
            "$image_name" \
            "$dockerfile"
    long_process_end
}

docker_startNginx() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting [ $name ] container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d -p 443:443 -p 80:80 --name=$name \
            -v /etc/letsencrypt:/etc/letsencrypt \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/var/www/html \
            $NGINX_MOUNTS \
            -e CERTBOT_DOMAINS="$BASE_URL" \
            --network=$RECIPE-net \
            $name:latest"
        ) > /dev/null
    long_process_end
}

docker_startPostgreSql() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting [ $name ] container on the host $remote_host"
        ssh -T "$remote_host" -i "$ssh_key" "docker run -d --name=$name \
            --restart=on-failure:3 \
            --network=$RECIPE-net \
            -e POSTGRES_DB=$POSTGRES_DB \
            -e POSTGRES_USER=root \
            -e POSTGRES_PASSWORD=root \
            -v $DATA_ROOT/postgres:/var/lib/postgresql/data \
            $name:latest"
    long_process_end
}

docker_startRedis() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting [ $name ] container on the host $remote_host"
        ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$name \
            --restart=on-failure:3 \
            --network=$RECIPE-net \
            --mount type=bind,source=$DATA_ROOT/redis,target=/data/redis \
            $name:latest"
    long_process_end
}

docker_startPhpFpm() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting Docker container [ $name ] on the host $remote_host"

        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$name \
            --mount type=bind,source=/tmp,target=/tmp \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/var/www/html \
            $PHP_FPM_MOUNTS \
            --network=$RECIPE-net \
            $name:latest"
        ) > /dev/null

    long_process_end
}

docker_startElasticsearch() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting $ELASTIC_CONTAINER container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$ELASTIC_CONTAINER \
            --network=$SUBSYSTEM-net \
            -e ES_JAVA_OPTS='-Xms256m -Xmx640m' \
            $ELASTIC_IMAGE_NAME:latest"
        ) > /dev/null
    long_process_end
}

docker_startMongoDb() {
    local remote_host="$1"
    local ssh_key="$2"
    local name="$3"

    long_process_start "Starting Docker container [ $name ] on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$name \
            --restart=on-failure:3 \
            --network=$RECIPE-net \
            --mount type=bind,source=$DATA_ROOT/mongodb,target=/data/mongodb \
            $name:latest"
        ) > /dev/null
    long_process_end
}

docker_startNodejs() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $NODEJS_CONTAINER container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d -p $NODEJS_PORTMAP --name=$NODEJS_CONTAINER \
            --restart=on-failure:3 \
            --network=$SUBSYSTEM-net \
            $NODEJS_IMAGE_NAME:latest"
        ) > /dev/null
    long_process_end
}

docker_getLastDockerImage() {
    local remote_host="$1"
    local pattern="$2"

    ssh "$remote_host" "docker images --format \"table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\" | sort -r -k4 | awk '\$2 ~ /$pattern/ {printf \"%s:%s\n\",\$2,\$3}' | head -n 1"
}

docker_cleanup() {
    local remote_host="$1"

    ssh -T "$remote_host" "images=\$(docker images | grep \"^<none>\" | awk \"{print \$3}\"); if [[ \$images ]]; then docker rmi \$images; fi"
}

docker_removeOldImages() {
    local remote_host="$1"
    local pattern="$2"

    ssh "$remote_host" <<EOF
        image_ids=\$(docker images --format \"table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\" | sort -r -k4 | awk '\$2 ~ /$pattern/ {print \$1}' | awk 'NR > 2 {print \$0}')
        [[ ! -z \$image_ids ]] && docker rmi \$image_ids
EOF
}
