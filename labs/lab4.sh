#!/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab ai

set -ue
set -o pipefail


CMD="${1:-help}"
DEBUG="${2:-}"
ME=$(basename "$0")


log(){
    message="$1"
    level="${2:-INFO}"
    cur_date="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "$cur_date [$level] $message"
}


# Check requirements
check() {
    if [ -z "$(which ip)" ]; then
        log "Need install iproute2 package" "ERROR"
        exit 1
    fi
    if [ -z "$(which docker)" ]; then
        log "Need install docker.io package" "ERROR"
        exit 1
    fi
    if [[ "$(whoami)" != "root" && ! "$DEBUG" ]]; then
        log "Please run as root" "ERROR"
        exit 1
    fi
}


# lock lab
lock() {
    files=(/tmp/lab*)
    if [ -e "${files[0]}" ]; then
        base_name=$(basename "${files[0]}")
        echo "$base_name was already created, please run: sudo ./$base_name delete"
        exit 1
    fi
    touch "/tmp/$ME"
}


# unlock lab
unlock() {
    rm -f "/tmp/$ME" || true
}


# Binary
[ -n "$DEBUG" ] && PRECMD="echo " || PRECMD=""
DOCKER="${PRECMD}$(which docker)"



# Lab params
DOCKER_NET_NAME="lab_network"
DOCKER_NET_SUBNET="172.18.0.0/16"
DOCKER_NET_ADDR="172.18.0.22"
DOCKER_CONTAINER_NAME="lab_container1"
DOCKER_IMAGE="ghcr.io/infraguys/debian_lab"


create() {
    lock
    log "Create test lab"

    log "Create docker network "$DOCKER_NET_NAME" with subnet $DOCKER_NET_SUBNET"
    $DOCKER network create --subnet="$DOCKER_NET_SUBNET" "$DOCKER_NET_NAME"
    $DOCKER run -d --privileged --net "$DOCKER_NET_NAME" --ip "$DOCKER_NET_ADDR" --name "$DOCKER_CONTAINER_NAME" -it "$DOCKER_IMAGE" /looper.sh
}


get_into_container() {
    log "Attach to container's shell"

    $DOCKER exec -it "$DOCKER_CONTAINER_NAME" bash
}


delete() {
    log "Delete test lab"

    log "Delete docker network "$DOCKER_NET_NAME" with subnet $DOCKER_NET_SUBNET"
    $DOCKER kill "$DOCKER_CONTAINER_NAME" || true
    $DOCKER rm "$DOCKER_CONTAINER_NAME" || true
    $DOCKER network rm "$DOCKER_NET_NAME" || true

    unlock
}


lab_test() {
    log "Run connectivity test in lab"

    # Check connectivity
    if [ -z "$DEBUG" ]; then
        ping -c 1 "$DOCKER_NET_ADDR" -W 0.5 && log "Test result: Success" || log "Test result: Failed" "ERROR"
    else
        echo "ping -c 1 "$DOCKER_NET_ADDR" -W 0.5"
        log "Test result: Undefined"
    fi
}


case "$CMD" in
    create)
        [ -n "$DEBUG" ] || check
        create
        ;;
    delete)
        [ -n "$DEBUG" ] || check
        delete
        ;;
    test)
        [ -n "$DEBUG" ] || check
        lab_test
        ;;
    task)
        log "
        Need successfull ping of $DOCKER_NET_ADDR address, which is configured in docker container ${DOCKER_CONTAINER_NAME}.
        Use '$ME get_into_container' to attach into container's shell if you want to try.

        Tools to look at:
        - ip netns attach
        - ip route
        "
        ;;
    get_into_container)
        get_into_container
        ;;
    *)
        log "Unknown command. Use {create|delete|test|task} [DEBUG]" "ERROR"
esac

exit 0
