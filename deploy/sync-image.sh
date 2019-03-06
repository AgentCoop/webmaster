#!/usr/bin/env bash

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

if [[ -z $IMAGE_LABEL ]]; then
    error "image name was not specified"
fi

imageName=$(docker_getImageName "$IMAGE_LABEL")
imageArchive="$imageName.tar"

if [[ ! -f "./builds/$imageName.tar" ]]; then
    error "docker image archive [ $imageArchive ] does not exist, run \`build\` command"
fi

HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/$RECIPE_NAME.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

while IFS=' ' read -r host key || [[ -n "$host" ]] && [[ -n "$key" ]]; do
    ssh_key="~/.ssh/$key"
    remote_host="$host"

    docker_syncImage "$remote_host" "$ssh_key" "$imageName"
done < "$HOSTS"