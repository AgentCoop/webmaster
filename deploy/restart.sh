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

hardRestart() {
    local remoteHost="$1"
    local sshKey="$2"
    local label="$3"

    docker_stopAndRemoveContainer "$remoteHost" "$sshKey" "$label"

    if [[ $label = 'redis' ]]; then
        docker_startRedis "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'mongodb' ]]; then
        docker_startMongoDb "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'postgresql' ]]; then
        docker_startPostgreSql "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'nginx' ]]; then
        docker_startNginx "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'nodejs' ]]; then
        docker_startNodejs "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'php-fpm' ]]; then
        docker_startPhpFpm "$remoteHost" "$sshKey" "$label"
    elif [[ $label = 'elasticsearch' ]]; then
        docker_startElasticsearch "$remoteHost" "$sshKey" "$label"
    fi
}

while IFS=' ' read -r remoteHost key || [[ -n "$remoteHost" ]] && [[ -n "$key" ]]; do
    sshKey="~/.ssh/$key"

    if [[ $HARD_RESTART = true ]]; then
        hardRestart "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    else
        docker_restartContainer "$remoteHost" "$sshKey" "$IMAGE_LABEL"
    fi
done < "$HOSTS"