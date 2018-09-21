#!/usr/bin/env bash

source "$ROOT_DIR/utils/index.sh"
source "$ROOT_DIR/../deploy/config_vars.sh"

declare -a SUBSYSTEMS

args=$(getopt --long host:,subsystem: -o "h:s:" -- "$@")

SERVICE_NAME=
SUPPORTED_SERVICES=(nginx php-fpm postgresql mongodb redis elasticsearch nodejs)
SUBSYSTEMS=($(find "$ROOT_DIR/../deploy/subsystem/" -type f  -exec basename {} .sh \;))

case "$(git_getCurrentBranchName)" in
    staging)
        RELEASE_TARGET=staging
    ;;
    master)
        RELEASE_TARGET=production
    ;;
    *)
        error "switch to the right branch to specify the release target"
    ;;
esac

load_subsystem_def() {
    SUBSYSTEM="$1"

    contains "$SUBSYSTEM" "${SUBSYSTEMS[@]}"

    if [[ $? != 0 ]]; then
        error "wrong subsystem name "$SUBSYSTEM" has been specified"
    fi

    source "$ROOT_DIR/../deploy/subsystem/$SUBSYSTEM.sh"
}

while [ $# -ge 1 ]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break
           ;;
        --subsystem)
            load_subsystem_def "$2"
        ;;
        -s)
            SERVICE_NAME="$2"
            contains "$SERVICE_NAME" "${SUPPORTED_SERVICES[@]}"

            if [[ $? != 0 ]]; then
                error "unsupported service $SERVICE_NAME"
            fi

            case "$2" in
                nginx)
                    NGINX_SERVICE=true
                ;;
                nodejs)
                    NODEJS_SERVICE=true
                ;;
                php)
                    PHP_SERVICE=true
                ;;
                mongodb)
                    MONGODB_SERVICE=true
                ;;
                postgresql)
                    POSTGRESQL_SERVICE=true
                ;;
                redis)
                    REDIS_SERVICE=true
                ;;
                elasticsearch)
                    ELASTICSEARCH_SERVICE=true
                ;;
                *)
                    error "unsupported service $2"
                ;;
            esac
        ;;
    esac

    shift
done

if [[ -z $SUBSYSTEM ]]; then
    error "application subsystem must be specified, --subsystem <NAME>"
fi