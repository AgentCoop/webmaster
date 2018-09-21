#!/usr/bin/env bash

# https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
#
# $ array=("something to search for" "a string" "test2000")
# $ containsElement "a string" "${array[@]}"
# $ echo $?
# 0
# $ containsElement "blaha" "${array[@]}"
# $ echo $?
# 1
contains() {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}