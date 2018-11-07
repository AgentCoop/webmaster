<p align="center">
    <img width="100%" height="256px" src="https://raw.githubusercontent.com/AgentCoop/webmaster/master/docs/banner.jpg" />
    <h1>Remember, Git is not a deployment tool</h1>
</p>

## Overview
Webmaster tools is and an old school way to deploy your code to production using Docker containers and Bash scripts.

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
