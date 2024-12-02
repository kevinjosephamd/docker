
set -e

# STEP 1 Build base image
DOCKER_FILE=$1
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
docker buildx build  -t base:kevin -f ${DOCKER_FILE} ${SCRIPT_DIR}

# STEP 2 Build dev image
# Create the actual dev image with the host user mirrored in the docker image
imageName=$(basename "$DOCKER_FILE" | cut -d. -f1 | awk '{print tolower($0)}')
echo "Creating the image: $imageName"
USERID=$(id -u)
docker build -t $imageName - << EOF
FROM base:kevin

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


USER $USER
ENV HOME /home/$USER
WORKDIR /home/$USER
ENV PS1 '\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
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

docker run --cap-add=SYS_PTRACE --ipc=host --privileged=true \
           --shm-size=128GB --network=host --device=/dev/kfd \
           --device=/dev/dri --group-add video \
           --group-add render \
           -v /home/$USER:/home/$USER \
           --user $USER \
           --name $CONTAINER_NAME \
           -d \
           $imageName tail -f /dev/null