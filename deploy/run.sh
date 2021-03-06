#!/usr/bin/env bash

set -e

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/$RECIPE_NAME.txt"

# Run a command from the given recipe
if [[ ! -z $COMMAND ]]; then

    if ! type $COMMAND >/dev/null 2>&1; then
        error 'unknown command has been given'
    fi

    $COMMAND

    exit $?
fi

if [[ ! -f $HOSTS ]]; then
    error "Hosts file $HOSTS does not exist"
fi

if ! type recipe >/dev/null 2>&1; then
    error "The given recipe does not define a `recipe` function"
fi

ARCHIVE="$RECIPE_NAME.$APP_NAME-$(date +%Y-%m-%d@%H_%M).tar.gz"

function cleanup {
    if [ ! -z $TEMP_CONT_ID ]; then
        docker stop $TEMP_CONT_ID
    fi

    rm -rf 2>/dev/null ./builds/tmp/*
    rm -rf 2>/dev/null ./builds/tmp/.*
}

trap cleanup EXIT

if type beforeRun >/dev/null 2>&1; then
    beforeRun
fi

while IFS=' ' read -r remote_host key || [[ -n "$remote_host" ]] && [[ -n "$key" ]]; do
    recipe "$remote_host" "~/.ssh/$key"
done < "$HOSTS"

if type afterRun >/dev/null 2>&1; then
    afterRun
fi

cleanup