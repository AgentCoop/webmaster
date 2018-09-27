#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

bold=$(tput bold)
normal=$(tput sgr0)

__indicator_end=
__indicator_pid=

__step_counter=1
__long_process_caption=

long_process_start() {
    __long_process_caption="$1"
    printf "\t[ Step $__step_counter ]${normal}\t${bold}${__long_process_caption}${normal}...\n"
}

long_process_end() {
    if [[ $? -eq 0 ]]; then
        printf "\t[ Step $__step_counter ]\t${GREEN}${bold}Finished${normal}${NC}\n\n"
    else
        printf "\t[ Step $__step_counter ]\t${RED}Failed${NC}\n"
    fi
    __step_counter=$((__step_counter + 1))
}

indicator_start() {
    __indicator_end="\r${bold}${1}${normal}... done\n"
    (
        while :;
            do for s in / - \\ \|;
                do printf "\r${bold}${1}${normal}... $s";
                sleep .1;
            done;
        done
    ) &

    __indicator_pid=$!
}

indicator_stop() {
    printf "$__indicator_end"

    kill -PIPE $__indicator_pid # Send SIGPIPE signal to prevent termination messages from being sent to the parent process
}

error () {
	tput setaf 1
	echo $'\t'Error: $1
	tput sgr0
	exit 1
}