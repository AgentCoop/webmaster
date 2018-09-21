#!/usr/bin/env bash

git_getCurrentBranchName() {
    git rev-parse --abbrev-ref HEAD
}

git_getHeadCommitHash() {
    git rev-parse --verify HEAD
}
