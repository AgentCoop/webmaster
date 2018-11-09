#!/usr/bin/env bash

BASE_DIR=./webmaster/sandbox/apps/laravel
DOCKER_DIR="$BASE_DIR/docker"
SOURCE_DIR="$BASE_DIR/app"
DOMAIN_NAMES="laravel-app.webmaster.asamuilik.info"

recipe() {
    local remote_host="$1"
    local ssh_key="$2"
    local contId=
    local imageName=$(docker_getDefaultImageContainerName "php-fpm")

    mkdir -p ./builds/tmp
    mkdir -p ./builds/tarballs

    rm -rf ./builds/tmp/*

    # Start a temporary container we are going to use for deployment
    contId=$(docker run -d -v  --rm "$imageName:latest")

    # Copy source code to the running container
    for target in app bootstrap config database public resources routes \
        artisan composer.json composer.lock package.json server.php webpack.mix.js;
    do
        docker cp "$SOURCE_DIR/$target" $contId:/var/www/html
    done

    # Copy some extra files
    docker cp "$DOCKER_DIR/php-fpm/$RELEASE_TARGET/.env" $contId:/var/www/html

    # Install vendor packages
    docker exec $contId composer install --no-dev -n

    docker cp $contId:/var/www/html/. ./builds/tmp/

    tar -zcf ./builds/tarballs/$ARCHIVE -C ./builds/tmp/ .

    long_process_start "Uploading archive to the host $remote_host"
        (
            ssh "$remote_host" -i "$ssh_key" mkdir -p $WEB_ROOT/archives
            scp -i "$ssh_key" ./builds/tarballs/$ARCHIVE $remote_host:$WEB_ROOT/archives/
        ) > /dev/null
    long_process_end

    long_process_start "Switching to the new code base on the host $remote_host"
        ( ssh -T "$remote_host" -i "$ssh_key" <<EOF
            RELEASE_DIR=$WEB_ROOT/releases/\$(date +%Y-%m-%d_%H_%M)
            mkdir -p \$RELEASE_DIR
            tar xzf $WEB_ROOT/archives/$ARCHIVE -C \$RELEASE_DIR/.
            rm -f $WEB_ROOT/releases/next
            ln -s \$RELEASE_DIR $WEB_ROOT/releases/next
            mv -fT $WEB_ROOT/releases/next $WEB_ROOT/releases/current
EOF
        ) > /dev/null
    long_process_end

    docker_hardRestart "$remote_host" "$ssh_key" "php-fpm"
    docker_hardRestart "$remote_host" "$ssh_key" "nginx"

    docker stop $contId
}


