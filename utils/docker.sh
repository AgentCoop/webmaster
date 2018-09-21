#!/usr/bin/env bash

docker_getContIdByName() {
    local cont_name="$1"
    $(docker ps -f "name=$cont_name" --format '{{.ID}}')
}

docker_buildImage() {
    local context="$1"
    local image_name="$2"
    local dockerfile=${3:-Dockerfile}

    if [[ ! -f $dockerfile ]]; then
        error "Dockerfile does not exist, $dockerfile"
    fi

    [[ ! -d ./builds ]] && mkdir ./builds

    local image_tag="$image_name":"latest"
    local image_archive="$imag_name".tar

    docker build \
        -f "$dockerfile" \
        -t "$image_tag" \
    "$context"

    docker save -o ./builds/"$image_archive" "$image_tag" >/dev/null
}

docker_reloadImage() {
    local remote_host="$1"
    local ssh_key="$2"
    local archive_name="$3".tar
    local images_dir='~/docker-images'

    timestamp=$(date +%Y-%m-%d_%H:%M)

    # Create directory for the image archive if not exists
    ssh -T "$remote_host" -i "$ssh_key"  "mkdir -p $images_dir"

    # Upload the image archive and load it
    scp -i "$ssh_key" "./builds/$archive_name" "$remote_host":"$images_dir" && \
    ssh -T "$remote_host" -i "$ssh_key" "docker load -q -i $images_dir/$archive_name >/dev/null"
}

docker_restartContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    ssh "$remote_host" -i "$ssh_key" "docker restart -t $DOCKER_RESTART_CONTAINER_TIMEOUT $cont_name"
}

docker_stopAndRemoveContainer() {
    local remote_host="$1"
    local ssh_key="$2"
    local cont_name="$3"

    ssh -T "$remote_host" -i "$ssh_key" <<EOF
        cont_id=\$(docker ps -aqf "name=$cont_name")
        [[ \$cont_id ]] && docker stop -t $DOCKER_STOP_CONTAINER_TIMEOUT \$cont_id && docker rm -f \$cont_id
        :
EOF

}

docker_getLastDockerImage() {
    local remote_host="$1"
    local pattern="$2"

    ssh "$remote_host" "docker images --format \"table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\" | sort -r -k4 | awk '\$2 ~ /$pattern/ {printf \"%s:%s\n\",\$2,\$3}' | head -n 1"
}

docker_cleanup() {
    local remote_host="$1"

    ssh -T "$remote_host" "images=\$(docker images | grep \"^<none>\" | awk \"{print \$3}\"); if [[ \$images ]]; then docker rmi \$images; fi"
}

docker_removeOldImages() {
    local remote_host="$1"
    local pattern="$2"

    ssh "$remote_host" <<EOF
        image_ids=\$(docker images --format \"table {{.ID}}\t{{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\" | sort -r -k4 | awk '\$2 ~ /$pattern/ {print \$1}' | awk 'NR > 2 {print \$0}')
        [[ ! -z \$image_ids ]] && docker rmi \$image_ids
EOF
}
