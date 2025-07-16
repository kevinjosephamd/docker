#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [OPTION]... [DOCKER_FILE]

Description:
  This script builds a Docker image from a specified Dockerfile. It creates and runs a container from this image.

Options:
  -h, --help    Show this help message and exit
  --no-cache    Force rebuild from base image.

Example:
  $0 ./Dockerfile
EOF
  1>&2;
  exit 1
}

no_cache=""
while (( $# )); do
  case "$1" in
    -h|--help)
        usage ;;
    --no-cache)
        no_cache="--no-cache"; shift ;;
    --)         # explicit end of flags: ./script -- --no-cache file.txt
        shift; break ;;
    -*)         # any other -something
        echo "ERROR: unknown option '$1'" >&2
        usage; ;;
    *)          # first non-flag -> positional arg(s)
        break ;;
  esac
done

if (( $# != 1 )); then
  echo "ERROR: exactly one positional argument expected" >&2
  usage
fi


# STEP 1 Build base image
DOCKER_FILE=$1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOCKER_VERSION=$(docker --version | grep -P -o  "Docker version \d+.\d+.\d+" | grep -P -o  -h  "\d+\.\d+\.\d+")
DOCKER_MAJOR_VERSION=$(echo ${DOCKER_VERSION} | cut -d'.' -f1)
BASE_IMAGE=base:${USER}_$(date +"%y-%m-%d")
DEV_IMAGE_NAME=$(basename "$DOCKER_FILE" | cut -d. -f1 | awk '{print tolower($0)}')
CONTAINER_NAME="${USER}_dev_container"

if [ ${DOCKER_MAJOR_VERSION} -gt 20 ];then
    docker buildx build  ${no_cache} -t ${BASE_IMAGE} -f ${DOCKER_FILE} ${SCRIPT_DIR}
else
    export DOCKER_BUILDKIT=1
    docker build -t ${no_cache} ${BASE_IMAGE} -f ${DOCKER_FILE} ${SCRIPT_DIR}
fi

# STEP 2 Build dev image
# Create the actual dev image with the host user mirrored in the docker image
echo "Creating the image: $DEV_IMAGE_NAME"
USERID=$(id -u)
RENDER_GROUP_ID=$(getent group render | cut -d: -f3)
VIDEO_GROUP_ID=$(getent group video | cut -d: -f3)
docker build -t $DEV_IMAGE_NAME - << EOF
FROM ${BASE_IMAGE}
RUN apt-get update
RUN apt-get install -y fish ripgrep less
RUN userdel -r ubuntu || true
RUN useradd -o -ms /bin/bash $USER -u $USERID
ARG DEBIAN_FRONTEND=noninteractive
# create the same user in docker as in outside
RUN apt-get install sudo
RUN  mkdir -p /home/$USER &&  \
    echo "$USER:x:1000:1000:$USER,,,:/home/$USER:/bin/bash" >> /etc/passwd && \
    echo "$USER:x:1000:" >> /etc/group && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER && \
    chown $USER:$USER -R /home/$USER
# Delete group if it exists
RUN groupdel render || exit 0
RUN groupadd -f -g ${RENDER_GROUP_ID} render
RUN groupadd -f -g ${VIDEO_GROUP_ID} video
USER $USER
RUN sudo chsh -s fish
ENV HOME /home/$USER
WORKDIR /home/$USER
ENV PS1 '\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
EOF

# Step 3 Create and launch container
echo "Stopping old $CONTAINER_NAME"
docker ps -q --filter name=$CONTAINER_NAME | xargs -I {} docker stop {}
docker ps -aq --filter name=$CONTAINER_NAME | xargs -I {} docker rm {}

ARGS="--cap-add=SYS_PTRACE \
           --ipc=host \
           --privileged=true \
           --shm-size=128GB \
           --network=host \
           -v /home/$USER:/home/$USER \
           --user $USER \
           --name $CONTAINER_NAME \
           -d"

if [[ -v NVIDIA_ENV ]]; then
  ARGS="${ARGS} --runtime=nvidia --gpus all"
else
  ARGS="${ARGS} \
           --security-opt seccomp=unconfined \
           --group-add render \
           --group-add video \
           --device=/dev/kfd \
           --device=/dev/dri"
fi

echo "Starting $CONTAINER_NAME"
docker run ${ARGS} \
           $DEV_IMAGE_NAME tail -f /dev/null
