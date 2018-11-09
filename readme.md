<p align="center">
    <h1>Remember, coder, Git is not a deployment tool!</h1>
    <img width="100%" height="480px" src="https://raw.githubusercontent.com/AgentCoop/webmaster/master/docs/banner.jpg" />
</p>

## Overview
Webmaster tools is an old school way to deploy your code to production using Docker containers and Bash scripts.

The demo below will show you how to deploy a Laravel application in few commands.

1. Build required Docker images
```bash
./deploy/build.sh -r laravel-app -i php-fpm --rdir ./sandbox/recipes
./deploy/build.sh -r laravel-app -i nginx --rdir ./sandbox/recipes
```

2. Deploy the images to production server
```bash
./webmaster/deploy/sync-images.sh --recipe laravel-app -i php-fpm
./webmaster/deploy/sync-images.sh --recipe laravel-app -i nginx
```

3. Build your app and deploy the code:
```bash
./deploy/run.sh -r laravel-app --rdir ./sandbox/recipes
```
That's it. Now your Laravel app is up and running. 1, 2 items are not something you will often do. Most likely, you will modify your application runtime environment from time to time. That's when you need to re-build and reload your Docker images.

## Installation
In the root directory of your application run the following commands:
```bash
$ git submodule add https://github.com/AgentCoop/webmaster.git
$ mkdir -p webmaster-recipes/hosts/{staging,production}
```
## Prerequisites
Remote hosts with Docker Engine installed.

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