#!/usr/bin/env bash

set -x
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" >/dev/null && pwd )"

source "$ROOT_DIR/deploy/__common.sh"

docker_build "$RELEASE_TARGET"