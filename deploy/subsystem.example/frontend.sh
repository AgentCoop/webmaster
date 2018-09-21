#!/usr/bin/env bash

DOCKER_DIR=./src/frontend/config/docker

if [[ $RELEASE_TARGET = 'staging' ]]; then
    BASE_URL=dev.trans.ru
elif [[ $RELEASE_TARGET = 'production' ]]; then
    BASE_URL=trans.ru
fi

NGINX_CONTAINER="nginx.frontend.transru"

NGINX_IMAGE_NAME="nginx.frontend.transru"

sync-code-base() {
    local release_target="$1"
    local remote_host="$2"
    local ssh_key="$3"
    local archive="$4"
    local T=./builds/tmp
    
    contId=$(docker ps | awk '$2 ~ /transru_reactjs/ {print $1}')

    if [[ -z $contId ]]; then
        error "Application must be running during the deployment!"
    fi

    mkdir -p ./builds/tmp
    mkdir -p ./builds/tarballs

    if [[ ! -f ./builds/tarballs/$archive ]]; then
        long_process_start "Building $release_target distro"
            docker exec -w /usr/src/app "$contId" '/usr/local/bin/npm' 'run' "$release_target:build"
            rm -rf "$T"/*
            docker cp "$contId":/usr/src/app/dist/. "$T"
            # Copy robots.txt
            cp ./src/frontend/public/robots.txt "$T"
        long_process_end

        long_process_start "Creating archive"
            tar -zcf ./builds/tarballs/$archive -C "$T" .
        long_process_end
    fi

    long_process_start "Uploading archive to the host $remote_host"
        ssh -T "$remote_host" -i "$ssh_key" mkdir -p $WEB_ROOT/archives
        scp -i "$ssh_key" ./builds/tarballs/$archive $remote_host:$WEB_ROOT/archives/
    long_process_end

    ( ssh -T "$remote_host" -i "$ssh_key" <<EOF
        mkdir -p $WEB_ROOT
        RELEASE_DIR=$WEB_ROOT/releases/\$(date +%Y-%m-%d_%H_%M)
        mkdir -p \$RELEASE_DIR
        tar xzf $WEB_ROOT/archives/$archive -C \$RELEASE_DIR/.
        rm -f $WEB_ROOT/releases/next
        ln -s \$RELEASE_DIR $WEB_ROOT/releases/next
        mv -fT $WEB_ROOT/releases/next $WEB_ROOT/releases/current
EOF
    ) > /dev/null
}

