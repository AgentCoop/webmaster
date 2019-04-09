#!/usr/bin/env bash

set -e

source "$ROOT_DIR/utils/index.sh"

declare -a RECIPES

args=$(getopt --long recipe:,image:,hard,rdir -o "h:r:i:c:" -- "$@")

COMMAND=
RECIPE_NAME=
USER_RECIPES_DIR=
HARD_RESTART=
IMAGE_NAME=
IMAGE_LABEL=
SUPPORTED_IMAGES=(nginx php-fpm postgresql mongodb redis elasticsearch nodejs)

case "$(git_getCurrentBranchName)" in
    staging)
        RELEASE_TARGET=staging
    ;;
    master)
        RELEASE_TARGET=production
    ;;
    *)
        error "Switch to the right branch to specify the release target"
    ;;
esac

loadRecipe() {
    contains "$RECIPE_NAME" "${RECIPES[@]}"

    if [[ $? != 0 ]]; then
        error "Wrong recipe "$RECIPE" has been specified"
    fi

    source "$USER_RECIPES_DIR/$RECIPE_NAME.sh"
}

while [ $# -ge 1 ]; do
    case "$1" in
        --)
            # No more options left.
            shift
            break
           ;;
        --recipe|-r)
            RECIPE_NAME="$2"
        ;;
        --hard)
            HARD_RESTART=true
        ;;
        -c)
            COMMAND="$2"
        ;;
        --rdir)
            USER_RECIPES_DIR="$(pwd)/$2"
        ;;
        --image|-i)
            IMAGE_LABEL="$2"
            contains "$IMAGE_LABEL" "${SUPPORTED_IMAGES[@]}"

            if [[ $? != 0 ]]; then
                error "Unsupported Docker image $IMAGE_LABEL"
            fi

            case "$2" in
                nginx)
                    NGINX_SERVICE=true
                ;;
                nodejs)
                    NODEJS_SERVICE=true
                ;;
                php-fpm)
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
                    error "Unsupported service $2"
                ;;
            esac
        ;;
    esac

    shift
done

# Set base recipes directory
USER_RECIPES_DIR=${USER_RECIPES_DIR:-$(realpath "$ROOT_DIR/../webmaster-recipes")}

if [[ -d "$USER_RECIPES_DIR"/extra ]]; then
    source "$USER_RECIPES_DIR"/extra/*.sh
fi

# Scan for available recipes
RECIPES=($(find "$USER_RECIPES_DIR/" -maxdepth 1 -type f -exec basename {} .sh \;))

if [[ -z $RECIPE_NAME ]]; then
    error "Recipe must be specified, --recipe <NAME>"
fi

loadRecipe
