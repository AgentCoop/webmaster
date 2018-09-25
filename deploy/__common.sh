#!/usr/bin/env bash

source "$ROOT_DIR/utils/index.sh"
source "$ROOT_DIR/../deploy/config_vars.sh"

declare -a RECIPES

args=$(getopt --long recipe:,image: -o "h:r:i:" -- "$@")

USER_DIR=$(realpath "$ROOT_DIR/../webmaster-recipes")
IMAGE_NAME=
SUPPORTED_IMAGES=(nginx php-fpm postgresql mongodb redis elasticsearch nodejs)
RECIPES=($(find "$USER_DIR/" -type f -maxdepth 1  -exec basename {} .sh \;))

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

loadRecipe() {
    RECIPE="$1"

    contains "$RECIPE" "${RECIPES[@]}"

    if [[ $? != 0 ]]; then
        error "wrong recipe "$RECIPE" has been specified"
    fi

    source "$USER_DIR/$RECIPE.sh"
}

while [ $# -ge 1 ]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break
           ;;
        --recipe|-r)
            loadRecipe "$2"
        ;;
        --image:-i)
            IMAGE_NAME="$2"
            contains "$IMAGE_NAME" "${SUPPORTED_IMAGES[@]}"

            if [[ $? != 0 ]]; then
                error "unsupported Docker image $IMAGE_NAME"
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

if [[ -z $RECIPE ]]; then
    error "recipe must be specified, --recipe <NAME>"
fi