<p align="center">
    <h1>Remember, coder, Git is not a deployment tool!</h1>
    <img width="100%" height="480px" src="https://raw.githubusercontent.com/AgentCoop/webmaster/master/docs/banner.jpg" />
</p>

## Overview
Webmaster tools is an old school way to deploy your code to production using Docker containers and Bash scripts. The demo below will show you how to deploy a Laravel application in few commands.

First, create a test application:
```bash
$ mkdir myapp && cd myapp && touch .gitignore && git init && git add . && git commit -m 'First commit'
$ git clone -b 'v0.0.2' --single-branch --depth 1 https://github.com/AgentCoop/webmaster.git
$ composer create-project --prefer-dist laravel/laravel webmaster/sandbox/apps/laravel/app
```

Now add SSH credentials for your remote host(s) to *./webmaster/sandbox/recipes/hosts/prod/laravel-app.txt*, the credentials must have the following format: user@ip_address ssh-key, where ssh-key is a SSH private key in ~/.ssh directory.

1. Build required Docker images
```bash
./webmaster/deploy/build.sh -r laravel-app -i php-fpm --rdir ./sandbox/recipes
./webmaster/deploy/build.sh -r laravel-app -i nginx --rdir ./sandbox/recipes
```

2. Deploy the images to production server
```bash
./webmaster/deploy/sync-images.sh --recipe laravel-app -i php-fpm
./webmaster/deploy/sync-images.sh --recipe laravel-app -i nginx
```

3. Build your app and deploy the code:
```bash
./webmaster/deploy/run.sh -r laravel-app --rdir ./sandbox/recipes
```
That's it. In less then 10 minutes you will have your Laravel app ready for production use.

1, 2 items are not something you will often do. Most likely, you will modify your application runtime environment from time to time. That's when you need to re-build and reload your Docker images.

## Installation
In the root directory of your application run the following commands:
```bash
$ git clone -b 'v0.0.2' --single-branch --depth 1 https://github.com/AgentCoop/webmaster.git
$ mkdir -p webmaster-recipes/hosts/{staging,prod}
```

*webmaster-recipes* is the default directory for the recipes. Do not forget to add it to your Git repository.

## Prerequisites
Remote host with Docker Engine installed.

## Deployment
Every time you want to deploy your code, switch to either staging or master branch. Everything on staging branch is being deployed to your staging server(s), everything on master - to production one(s), this is quite obvious behavior.

A recipe is nothing else than a Bash script containing instruction for deployment.

A typical recipe looks like:
```bash
#!/usr/bin/env bash

set -e

BASE_DIR=./webmaster/sandbox/apps/laravel
DOCKER_DIR="$BASE_DIR/docker"
SOURCE_DIR="$BASE_DIR/app"
DOMAIN_NAMES="laravel-app.webmaster.asamuilik.info"

beforeRun() {
    echo 'before'
}

afterRun() {
    echo 'after'
}

recipe() {
    echo 'Do some work'
}
```