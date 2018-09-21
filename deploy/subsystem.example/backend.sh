#!/usr/bin/env bash

DOCKER_DIR=./src/backend/config/docker
SOURCE_DIR=./src/backend

if [[ $RELEASE_TARGET = 'staging' ]]; then
    BASE_URL=api.dev.myapp.com
elif [[ $RELEASE_TARGET = 'production' ]]; then
    BASE_URL=api.myapp.com
fi

POSTGRES_DB=trans_ru_db

POSTGRES_CONTAINER="postgresql.api.myapp"
REDIS_CONTAINER="redis.api.myapp"
PHP_CONTAINER="php.api.myapp"
NGINX_CONTAINER="nginx.api.myapp"
ELASTICSEARCH_CONTAINER="elasticsearch.api.myapp"

POSTGRES_IMAGE_NAME="postgresql.api.myapp"
REDIS_IMAGE_NAME="redis.api.myapp"
PHP_IMAGE_NAME="php.api.myapp"
NGINX_IMAGE_NAME="nginx.api.myapp"
ELASTICSEARCH_IMAGE_NAME="elasticsearch.api.myapp"

NGINX_MOUNTS="\
        --mount type=bind,source=$DATA_ROOT/app/public,target=/var/www/html/public/storage \
"

sync-code-base() {
    local release_target="$1"
    local remote_host="$2"
    local ssh_key="$3"
    local archive="$4"
    local T=./builds/tmp
    local DOCKER_CONFIG=./builds/tmp/config/docker

    contId=$(docker ps | awk '$2 ~ /transru_php/ {print $1}')

    if [[ -z $contId ]]; then
        error "Application must be running during the deployment!"
    fi

    mkdir -p ./builds/tmp
    mkdir -p ./builds/tarballs

    rm -rf ./builds/tmp/*

    if [[ ! -f ./builds/tarballs/$archive ]]; then
        long_process_start "Copying app source code files from $PHP_CONTAINER container"
            docker cp $contId:/var/www/html/. ./builds/tmp/

            cp "$DOCKER_DIR/php/$release_target/.env" ./builds/tmp/

            rm -rf $T/node_modules
            rm -rf $T/logs
            rm -rf $T/storage/app/*
            rm -rf $T/tests
            rm -f $T/Dockerfile $T/package.json $T/phpunit.xml $T/readme.md $T/supervisor.log $T/supervisor.pid \
                $T/yarn.lock
        long_process_end

        long_process_start "Creating archive"
            tar -zcf ./builds/tarballs/$archive -C "$T" .
        long_process_end
    fi

    long_process_start "Uploading archive to the host $remote_host"
        (
            ssh "$remote_host" -i "$ssh_key" mkdir -p $WEB_ROOT/archives
            scp -i "$ssh_key" ./builds/tarballs/$archive $remote_host:$WEB_ROOT/archives/
        ) > /dev/null
    long_process_end

    long_process_start "Switching to the new code base on the host $remote_host"
        ( ssh -T "$remote_host" -i "$ssh_key" <<EOF
            RELEASE_DIR=$WEB_ROOT/releases/\$(date +%Y-%m-%d_%H_%M)
            mkdir -p \$RELEASE_DIR
            mkdir -p $DATA_ROOT/app/public
            mkdir -p $DATA_ROOT/app/system/framework/cache
            mkdir -p $DATA_ROOT/app/system/framework/views
            mkdir -p $DATA_ROOT/app/system/framework/sessions
            tar xzf $WEB_ROOT/archives/$archive -C \$RELEASE_DIR/.
            rm -f $WEB_ROOT/releases/next
            ln -s \$RELEASE_DIR $WEB_ROOT/releases/next
            mv -fT $WEB_ROOT/releases/next $WEB_ROOT/releases/current
EOF
        ) > /dev/null
    long_process_end
}


