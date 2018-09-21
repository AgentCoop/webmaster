#!/usr/bin/env bash

docker_getContIdByName() {
    local cont_name="$1"
    $(docker ps -f "name=$cont_name" --format '{{.ID}}')
}

docker_buildImage() {
    local context="$1"
    local image_name="$2"
    local dockerfile=${3:-Dockerfile}

    if [[ ! -f $dockerfile ]]; then
        error "Dockerfile does not exist, $dockerfile"
    fi

    [[ ! -d ./builds ]] && mkdir ./builds

    local image_tag="$image_name":"latest"
    local image_archive="$imag_name".tar

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

docker_stopAndRemoveContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    ssh -T "$remote_host" -i "$ssh_key" <<EOF
        cont_id=\$(docker ps -aqf "name=$cont_name")
        [[ \$cont_id ]] && docker stop -t $DOCKER_STOP_CONTAINER_TIMEOUT \$cont_id && docker rm -f \$cont_id
        :
EOF

}

docker_syncImage() {
    local remote_host="$1"
    local ssh_key="$2"
    local image_name="$3"

    long_process_start "Uploading Docker image $image_name to the target host $remote_host"
        reload_image "$remote_host" "$ssh_key" "$image_name"
    long_process_end
}

docker_syncAllImages() {
    local remote_host="$1"
    local ssh_key="$2"

    # Just to be sure that all directories, which are about to be mounted by containers, exist
    ( ssh -T "$remote_host" -i "$ssh_key" <<EOF
        mkdir -p $WEB_ROOT
        mkdir -p $DATA_ROOT
EOF
    ) > /dev/null

    if [[ $NGINX_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$NGINX_IMAGE_NAME"
    fi

    if [[ $PHP_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$PHP_IMAGE_NAME"
    fi

    if [[ $POSTGRESQL_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$POSTGRESQL_IMAGE_NAME"
    fi

    if [[ $REDIS_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$REDIS_IMAGE_NAME"
    fi

    if [[ $ELASTICSEARCH_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$ELASTICSEARCH_IMAGE_NAME"
    fi

    if [[ $MONGODB_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$MONGODB_IMAGE_NAME"
    fi

    if [[ $NODEJS_SERVICE = true ]]; then
        docker_syncImage "$remote_host" "$ssh_key" "$NODEJS_IMAGE_NAME"
    fi
}

docker_build() {
    local release_target="$1"

    if [[ $POSTGRESQL_SERVICE = true ]]; then
        local context="$DOCKER_DIR/postgresql/$release_target/."

        long_process_start "Building $POSTGRES_IMAGE_NAME image"
            build_image "$context" \
                "$POSTGRESQL_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi

    if [[ $REDIS_SERVICE = true ]]; then
        local context="$DOCKER_DIR/redis/$release_target/."

        long_process_start "Building $REDIS_IMAGE_NAME image"
            build_image "$context" \
                "$REDIS_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi

    if [[ $PHP_SERVICE = true ]]; then
        local context="$SOURCE_DIR/."

        long_process_start "Building $PHP_IMAGE_NAME image"
            build_image "$context" \
                "$PHP_IMAGE_NAME" \
                "$DOCKER_DIR/php/$release_target/Dockerfile"
        long_process_end
    fi

    if [[ $NGINX_SERVICE = true ]]; then
        local context="$DOCKER_DIR/nginx/$release_target/."

        long_process_start "Building $NGINX_IMAGE_NAME image"
            build_image "$context" \
                "$NGINX_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi

    if [[ $ELASTICSEARCH_SERVICE = true ]]; then
        local context="$DOCKER_DIR/elastic/$release_target/."

        long_process_start "Building $ELASTIC_IMAGE_NAME image"
            build_image "$context" \
                "$ELASTIC_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi

    if [[ $NODEJS_SERVICE = true ]]; then
        local context="$DOCKER_DIR/nodejs/$release_target/."

        long_process_start "Building $NODEJS_IMAGE_NAME image"
            build_image "$SOURCE_DIR/." \
                "$NODEJS_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi

    if [[ $MONGODB_SERVICE = true ]]; then
        local context="$DOCKER_DIR/mongodb/$release_target"

        long_process_start "Building $MONGODB_IMAGE_NAME image"
            build_image "$context/." \
                "$MONGODB_IMAGE_NAME" \
                "$context/Dockerfile"
        long_process_end
    fi
}

docker_startNginx() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $NGINX_CONTAINER container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d -p 443:443 -p 80:80 --name=$NGINX_CONTAINER \
            -v /etc/letsencrypt:/etc/letsencrypt \
            -v $WEB_ROOT/releases/current:/var/www/html \
            $NGINX_MOUNTS \
            -e CERTBOT_DOMAINS="$BASE_URL" \
            --network=$SUBSYSTEM-net \
            $NGINX_IMAGE_NAME:latest"
        ) > /dev/null
    long_process_end
}

docker_stopNginx() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $NGINX_CONTAINER container on $remote_host"
        ( stop_container "$remote_host" "$ssh_key" "$NGINX_CONTAINER" ) > /dev/null
    long_process_end
}

restart_nginx() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $NGINX_CONTAINER container on $remote_host"
        (
            stop_nginx "$remote_host" "$ssh_key"
            start_nginx "$remote_host" "$ssh_key"
        ) > /dev/null
    long_process_end
}

start_postgres() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $POSTGRES_CONTAINER container on the host $remote_host"
        ssh -T "$remote_host" -i "$ssh_key" "docker run -d --name=$POSTGRES_CONTAINER \
            --restart=on-failure:3 \
            --network=$SUBSYSTEM-net \
            -e POSTGRES_DB=$POSTGRES_DB \
            -e POSTGRES_USER=root \
            -e POSTGRES_PASSWORD=root \
            -v $DATA_ROOT/postgres:/var/lib/postgresql/data \
            $POSTGRES_IMAGE_NAME:latest"
    long_process_end
}

stop_postgres() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $POSTGRES_CONTAINER container on the host $remote_host"
        ( stop_container "$remote_host" "$ssh_key" "$POSTGRES_CONTAINER" ) > /dev/null
    long_process_end
}

restart_postgres() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $POSTGRES_CONTAINER container on the host $remote_host"
        (
            stop_postgres "$remote_host" "$ssh_key" "$POSTGRES_CONTAINER"
            start_postgres "$remote_host" "$ssh_key" "$POSTGRES_CONTAINER"
        ) > /dev/null
    long_process_end
}

start_redis() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $REDIS_CONTAINER container on the host $remote_host"
        ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$REDIS_CONTAINER \
            --restart=on-failure:3 \
            --network=$SUBSYSTEM-net \
            -v $DATA_ROOT/redis:/data/redis \
            $REDIS_IMAGE_NAME:latest"
    long_process_end
}

stop_redis() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $REDIS_CONTAINER container on the host $remote_host"
        (
            stop_container "$remote_host" "$ssh_key" "$REDIS_CONTAINER"
        ) > /dev/null
    long_process_end
}

restart_redis() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $REDIS_CONTAINER container on the host $remote_host"
        (
            stop_redis "$remote_host" "$ssh_key" "$REDIS_CONTAINER"
            start_redis "$remote_host" "$ssh_key" "$REDIS_CONTAINER"
        ) > /dev/null
    long_process_end
}

start_php() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $PHP_CONTAINER container on the host $remote_host"

        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$PHP_CONTAINER \
            -v /tmp:/tmp \
            --mount type=bind,source=$WEB_ROOT/releases/current,target=/var/www/html \
            --mount type=bind,source=$DATA_ROOT/app/public,target=/var/www/html/storage/app \
            --mount type=bind,source=$DATA_ROOT/app/system,target=/var/www/html/storage \
            --network=$SUBSYSTEM-net \
            $PHP_IMAGE_NAME:latest"
        ) > /dev/null

    long_process_end
}

stop_php() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $PHP_CONTAINER container on the host $remote_host"
    ( stop_container "$remote_host" "$ssh_key" "$PHP_CONTAINER" ) > /dev/null
    long_process_end
}

restart_php() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $PHP_CONTAINER container on $remote_host"
        (
            stop_php "$remote_host" "$ssh_key" "$PHP_CONTAINER"
            start_php "$remote_host" "$ssh_key" "$PHP_CONTAINER"
        ) > /dev/null
    long_process_end
}

start_elasticsearch() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $ELASTIC_CONTAINER container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$ELASTIC_CONTAINER \
            --network=$SUBSYSTEM-net \
            -e ES_JAVA_OPTS='-Xms256m -Xmx640m' \
            $ELASTIC_IMAGE_NAME:latest"
        ) > /dev/null
    long_process_end
}

stop_elasticsearch() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $ELASTIC_CONTAINER container on the host $remote_host"
        ( stop_container "$remote_host" "$ssh_key" "$ELASTIC_CONTAINER" ) > /dev/null
    long_process_end
}

restart_elasticsearch() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $ELASTIC_CONTAINER container on $remote_host"
        (
            stop_elasticsearch "$remote_host" "$ssh_key"
            start_elasticsearch "$remote_host" "$ssh_key"
        ) > /dev/null
    long_process_end
}

start_mongodb() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Starting $MONGODB_CONTAINER container on the host $remote_host"
        ( ssh "$remote_host" -i "$ssh_key" "docker run -d --name=$MONGODB_CONTAINER \
            --restart=on-failure:3 \
            --network=$SUBSYSTEM-net \
            -v $DATA_ROOT/mongodb:/data/mongodb \
            $MONGODB_IMAGE_NAME:latest"
        ) > /dev/null
    long_process_end
}

stop_mongodb() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $MONGODB_CONTAINER container on the host $remote_host"
        (
            stop_container "$remote_host" "$ssh_key" "$MONGODB_CONTAINER"
        ) > /dev/null
    long_process_end
}

restart_mongodb() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $MONGODB_CONTAINER container on $remote_host"
        (
            stop_mongodb "$remote_host" "$ssh_key"
            start_mongodb "$remote_host" "$ssh_key"
        ) > /dev/null
    long_process_end
}

start_nodejs() {
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

stop_nodejs() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Stopping and removing $NODEJS_CONTAINER container on the host $remote_host"
        (
            stop_container "$remote_host" "$ssh_key" "$NODEJS_CONTAINER"
        ) > /dev/null
    long_process_end
}

restart_nodejs() {
    local remote_host="$1"
    local ssh_key="$2"

    long_process_start "Restarting $NODEJS_CONTAINER container on $remote_host"
        (
            stop_nodejs "$remote_host" "$ssh_key"
            start_nodejs "$remote_host" "$ssh_key"
        ) > /dev/null
    long_process_end
}

restart() {
    local remote_host="$1"
    local ssh_key="$2"

    if [[ $NGINX_SERVICE = true ]]; then
        restart_nginx "$remote_host" "$ssh_key" "$NGINX_IMAGE_NAME"
    fi

    if [[ $PHP_SERVICE = true ]]; then
        restart_php "$remote_host" "$ssh_key" "$PHP_IMAGE_NAME"
    fi

    if [[ $POSTGRES_SERVICE = true ]]; then
        restart_postgres "$remote_host" "$ssh_key" "$POSTGRES_IMAGE_NAME"
    fi

    if [[ $REDIS_SERVICE = true ]]; then
        restart_redis "$remote_host" "$ssh_key" "$REDIS_IMAGE_NAME"
    fi

    if [[ $ELASTIC_SERVICE = true ]]; then
        restart_elasticsearch "$remote_host" "$ssh_key" "$ELASTIC_IMAGE_NAME"
    fi

    if [[ $MONGODB_SERVICE = true ]]; then
        restart_mongodb "$remote_host" "$ssh_key" "$MONGODB_IMAGE_NAME"
    fi

    if [[ $NODEJS_SERVICE = true ]]; then
        restart_nodejs "$remote_host" "$ssh_key" "$NODEJS_IMAGE_NAME"
    fi
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
