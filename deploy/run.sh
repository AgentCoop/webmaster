#!/usr/bin/env bash

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/$RECIPE.txt"

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

ARCHIVE="$RECIPE.$APP_NAME-$(date +%Y-%m-%d@%H_%M).tar.gz"

while IFS=' ' read -r remote_host key || [[ -n "$remote_host" ]] && [[ -n "$key" ]]; do
    recipe "$RELEASE_TARGET" "$remote_host" "~/.ssh/$key" "$ARCHIVE"
done < "$HOSTS"

rm -rf ./builds/tarballs/*