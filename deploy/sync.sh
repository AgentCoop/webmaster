#!/usr/bin/env bash

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

if [[ -z $SERVICE_NAME ]]; then
    error "service name was not specified"
fi

image_name=$(docker_getDefaultImageContainerName)
image_archive="$image_name.tar"

if [[ ! -f "./builds/$image_name.tar" ]]; then
    error "docker image archive [ $image_archive ] does not exist, run \`build\` command"
fi

HOSTS="$ROOT_DIR/../deploy/hosts/$RELEASE_TARGET/$SUBSYSTEM.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

while IFS=' ' read -r host key || [[ -n "$host" ]] && [[ -n "$key" ]]; do
    ssh_key="~/.ssh/$key"
    remote_host="$host"

    docker_syncImage "$remote_host" "$ssh_key" "$image_name"
done < "$HOSTS"