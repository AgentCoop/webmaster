#!/usr/bin/env bash

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

if [[ -z $IMAGE_NAME ]]; then
    error "image name was not specified"
fi

cont_name=$(docker_getDefaultImageContainerName)

HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/$RECIPE_NAME.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

hardRestart() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    docker_stopAndRemoveContainer "$remote_host" "$ssh_key" "$cont_name"

    if [[ $IMAGE_NAME = 'redis' ]]; then
        docker_startRedis "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'mongodb' ]]; then
        docker_startMongoDb "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'postgresql' ]]; then
        docker_startPostgreSql "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'nginx' ]]; then
        docker_startNginx "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'nodejs' ]]; then
        docker_startNodejs "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'php-fpm' ]]; then
        docker_startPhpFpm "$remote_host" "$ssh_key" "$cont_name"
    elif [[ $IMAGE_NAME = 'elasticsearch' ]]; then
        docker_startElasticsearch "$remote_host" "$ssh_key" "$cont_name"
    fi
}

while IFS=' ' read -r remote_host key || [[ -n "$remote_host" ]] && [[ -n "$key" ]]; do
    ssh_key="~/.ssh/$key"

    if [[ $HARD_RESTART = true ]]; then
        hardRestart "$remote_host" "$ssh_key" "$cont_name"
    else
        docker_restartContainer "$remote_host" "$ssh_key" "$cont_name"
    fi
done < "$HOSTS"