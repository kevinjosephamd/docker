
set -e

# STEP 1 Build base image
DOCKER_FILE=$1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DOCKER_VERSION=$(docker --version | grep -P -o  "Docker version \d+.\d+.\d+" | grep -P -o  -h  "\d+\.\d+\.\d+")
DOCKER_MAJOR_VERSION=$(echo ${DOCKER_VERSION} | cut -d'.' -f1)

if [ ${DOCKER_MAJOR_VERSION} -gt 20 ];then
    docker buildx build  -t base:${USER} -f ${DOCKER_FILE} ${SCRIPT_DIR}
else
    export DOCKER_BUILDKIT=1
    docker build -t base:${USER} -f ${DOCKER_FILE} ${SCRIPT_DIR}
fi

# STEP 2 Build dev image
# Create the actual dev image with the host user mirrored in the docker image
imageName=$(basename "$DOCKER_FILE" | cut -d. -f1 | awk '{print tolower($0)}')
echo "Creating the image: $imageName"
USERID=$(id -u)
RENDER_GROUP_ID=$(getent group render | cut -d: -f3)
VIDEO_GROUP_ID=$(getent group video | cut -d: -f3)

read -p "Enter container password to set: " CONTAINER_PASSWORD

docker build -t $imageName - << EOF
FROM base:${USER}

RUN useradd -ms /bin/bash $USER -u $USERID
ARG DEBIAN_FRONTEND=noninteractive

# create the same user in docker as in outside
RUN apt-get update
RUN apt-get install sudo
RUN  mkdir -p /home/$USER &&  \
    echo "$USER:x:1000:1000:$USER,,,:/home/$USER:/bin/bash" >> /etc/passwd && \
    echo "$USER:x:1000:" >> /etc/group && \
    echo "$USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER && \
    chown $USER:$USER -R /home/$USER
# Setup for sshd
RUN echo "$USER:$CONTAINER_PASSWORD" | chpasswd
RUN mkdir /var/run/sshd
# Delete group if it exists
RUN groupdel render; exit 0
RUN groupadd -f -g ${RENDER_GROUP_ID} render
RUN groupadd -f -g ${VIDEO_GROUP_ID} video

USER $USER
ENV HOME /home/$USER
WORKDIR /home/$USER
ENV PS1 '\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
ENTRYPOINT sudo sshd -p 6666 && tail -f /dev/null
EOF

# Step 3 Create and launch container
CONTAINER_NAME="${imageName}_container"
if [ "$(docker ps | grep -o $CONTAINER_NAME)" = "$CONTAINER_NAME" ]
then
    echo "Stopping running container"
    docker stop $CONTAINER_NAME
fi

if [ "$(docker container ls -a | grep -o $CONTAINER_NAME)" = "$CONTAINER_NAME" ]
then
    echo "Removing old container"
    docker rm $CONTAINER_NAME
fi

ARGS="--cap-add=SYS_PTRACE \
           --ipc=host \
           --privileged=true \
           --shm-size=128GB \
           --network=host \
           --security-opt seccomp=unconfined \
           --group-add render \
           --group-add video \
           --device=/dev/kfd \
           --device=/dev/dri \
           -v /home/$USER:/home/$USER \
           --user $USER \
           --name $CONTAINER_NAME \
           -d"

docker run ${ARGS} \
           $imageName