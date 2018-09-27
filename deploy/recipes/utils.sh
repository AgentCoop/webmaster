#!/usr/bin/env bash

##
## Examples of recipes turning on/off maintenance mode on frontend servers
##

maintenanceOn() {
    local HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/frontend.txt"
    local remote_host=
    local key=

    if [[ ! -f $HOSTS ]]; then
        error "hosts file $HOSTS does not exist"
    fi

    while IFS=' ' read -r remote_host key || [[ -n "$remote_host" ]] && [[ -n "$key" ]]; do
        long_process_start "Maintenance on, host $remote_host (frontend)"
            (
                scp -i "~/.ssh/$key" ./src/backend/maintenance.html "$remote_host":"$WEB_ROOT/releases/current"
            ) > /dev/null
        long_process_end
    done < "$HOSTS"
}

maintenanceOff() {
    local HOSTS="$USER_RECIPES_DIR/hosts/$RELEASE_TARGET/frontend.txt"
    local remote_host=
    local key=

    if [[ ! -f $HOSTS ]]; then
        error "hosts file $HOSTS does not exist"
    fi

    while IFS=' ' read -r remote_host key || [[ -n "$remote_host" ]] && [[ -n "$key" ]]; do
        long_process_start "Maintenance off, host $remote_host (frontend)"
            (
                ssh -i "~/.ssh/$key" "$remote_host" rm -f "$WEB_ROOT/releases/current/maintenance.html"
            ) > /dev/null
        long_process_end
    done < "$HOSTS"
}