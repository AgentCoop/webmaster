#!/usr/bin/env bash

#set -x
set -e

source ./webmaster/config_vars.sh
source ./webmaster/utils/index.sh
source ./webmaster/deploy/__common.sh

WEB_ROOT=/app/transru/web
DATA_ROOT=/app/transru/data

COMMAND=$1
shift

SUBSYSTEM=

sync-clean() {
   rm -rf ./builds/tmp/*
   rm -rf ./builds/tarballs/*
}

maintenance_on() {
    local HOSTS="./scripts/deploy/hosts/$RELEASE_TARGET/frontend.txt"

    if [[ ! -f $HOSTS ]]; then
        error "Hosts file $HOSTS does not exist"
    fi

    while IFS=' ' read -r host key || [[ -n "$host" ]] && [[ -n "$key" ]]; do
        scp -i "~/.ssh/$key" ./src/backend/maintenance.html "$host":"$WEB_ROOT/releases/current"
    done < "$HOSTS"
}

maintenance_off() {
    local HOSTS="./scripts/deploy/hosts/$RELEASE_TARGET/frontend.txt"

    if [[ ! -f $HOSTS ]]; then
        error "Hosts file $HOSTS does not exist"
    fi

    while IFS=' ' read -r host key || [[ -n "$host" ]] && [[ -n "$key" ]]; do
        ssh -i "~/.ssh/$key" "$host" rm -f "$WEB_ROOT/releases/current/maintenance.html"
    done < "$HOSTS"
}

# Build docker images
if [[ $COMMAND == "build" ]]; then
    build "$RELEASE_TARGET"

    exit
fi

if [[ $COMMAND == "maintenance-on" ]]; then
    maintenance_on
    exit
fi

if [[ $COMMAND == "maintenance-off" ]]; then
    maintenance_off
    exit
fi

PHP_SOURCE_CODE=transru-backend-$(date +%Y-%m-%d@%H_%M).tar.gz
FRONTEND_DISTRO=transru-frontend-$(date +%Y-%m-%d@%H_%M).tar.gz
ADMIN_DISTRO=transru-admin-$(date +%Y-%m-%d@%H_%M).tar.gz

HOSTS="./scripts/deploy/hosts/$RELEASE_TARGET/$SUBSYSTEM.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

while IFS=' ' read -r host key || [[ -n "$host" ]] && [[ -n "$key" ]]; do
    SSH_KEY="~/.ssh/$key"
    REMOTE_HOST="$host"

    case $COMMAND in
        sync)
            maintenance_on

            if [[ $SUBSYSTEM == "backend" ]]; then
                sync-code-base "$RELEASE_TARGET" "$REMOTE_HOST" "$SSH_KEY" "$PHP_SOURCE_CODE"

                # Now we can restart PHP container
                PHP_SERVICE=true
                restart "$REMOTE_HOST" "$SSH_KEY"

            elif [[ $SUBSYSTEM  == "frontend" ]]; then
                sync-code-base "$RELEASE_TARGET" "$REMOTE_HOST" "$SSH_KEY" "$FRONTEND_DISTRO"

                NGINX_SERVICE=true
                restart "$REMOTE_HOST" "$SSH_KEY"
            elif [[ $SUBSYSTEM  == "admin" ]]; then
                sync-code-base "$RELEASE_TARGET" "$REMOTE_HOST" "$SSH_KEY" "$ADMIN_DISTRO"

                NGINX_SERVICE=true
                restart "$REMOTE_HOST" "$SSH_KEY"
            fi
        ;;
        restart)
            restart "$REMOTE_HOST" "$SSH_KEY"
        ;;
        sync-images)
            build "$RELEASE_TARGET"
            sync_images "$REMOTE_HOST" "$SSH_KEY"

            if [[ $SUBSYSTEM == "chat" ]]; then
                NODEJS_SERVICE=true
                restart "$REMOTE_HOST" "$SSH_KEY"
            fi
        ;;
    esac
done < "$HOSTS"

if [[ $COMMAND == "sync" ]]; then
    #sync-clean
    echo
fi