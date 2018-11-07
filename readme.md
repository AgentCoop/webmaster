<p align="center">
    <h1>Remember, coder, Git is not a deployment tool!</h1>
    <img width="100%" height="480px" src="https://raw.githubusercontent.com/AgentCoop/webmaster/master/docs/banner.jpg" />
</p>

## Overview
Webmaster tools is an old school way to deploy your code to production using Docker containers and Bash scripts.

In a nutshell:
1. Build your Docker image
```bash
./webmaster/deploy/build.sh --recipe backend -i php-fpm
```

2. Deploy the image to production server
```bash
./webmaster/deploy/sync-images.sh --recipe backend -i php-fpm
```

3. Build your app and deploy the code:
```bash
./webmaster/deploy/run.sh --recipe backend
```

## Installation
In the root directory of your application run the following commands:
```bash
$ git submodule add https://github.com/AgentCoop/webmaster.git
$ mkdir -p webmaster-recipes/hosts/{staging,production}
```

## Deployment
Every time you want to deploy your code, switch to either staging or master branch. Everything on staging branch is being deployed to your staging server(s), everything on master - to production one(s), this is quite obvious behavior.

*./webmaster-recipes/hosts/* directory holds files with IP address/SSH-key-name pairs for all of your hosts. For instance, the content of ./webmaster-recipes/hosts/production/backend.txt might look like 23.23.23.23 prod-key, where prod-key is a private SSH key in ~/.ssh/.

A recipe is nothing else than a Bash script containing instruction for deployment. In our example, for the recipe backend, there will be corresponding ./webmaster-recipe/backend.sh script.

A typical recipe looks like:
```bash
#!/usr/bin/env bash

set -e

DOCKER_DIR=./src/backend/config/docker

beforeRun() {
    echo 'before'
}

afterRun() {
    echo 'after'
}

recipe() {
    echo 'Do some deployment'
}
```