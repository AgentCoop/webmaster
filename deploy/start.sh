#!/usr/bin/env bash

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

if [[ -z $IMAGE_LABEL ]]; then
    error "image name was not specified"
fi

HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/$RECIPE_NAME.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

while IFS=' ' read -r remoteHost key || [[ -n "$remoteHost" ]] && [[ -n "$key" ]]; do
    sshKey="~/.ssh/$key"

    if [[ $IMAGE_NAME = 'redis' ]]; then
        docker_startRedis "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'mongodb' ]]; then
        docker_startMongoDb "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'postgresql' ]]; then
        docker_startPostgreSql "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'nginx' ]]; then
        docker_startNginx "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'nodejs' ]]; then
        docker_startNodejs "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'php-fpm' ]]; then
        docker_startPhpFpm "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    elif [[ $IMAGE_NAME = 'elasticsearch' ]]; then
        docker_startElasticsearch "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    fi
done < "$HOSTS"