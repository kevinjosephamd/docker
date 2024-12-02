CONTAINER_NAME=$1

if [ "$CONTAINER_NAME" = "" ]
then
    echo "Enter container name to attach to. Usage: attach.sh <CONTAINER_NAME>"
    exit
fi

docker exec -it -e force_color_prompt=yes -u $USER:$USER ${CONTAINER_NAME} bash