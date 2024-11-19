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
IP="${PRECMD}$(which ip)"

# Lab params
# Main netns params
IP_MAIN_NS="192.168.100.1"
MAC_MAIN_NS="fa:16:3e:00:00:01"
# Router netns params
ROUTER_NS_NAME="router"
IP_ROUTER_MAIN_NS="192.168.100.2"
MAC_ROUTER_MAIN_NS="fa:16:3e:00:00:02"
IP_ROUTER_CLIENT_NS="192.168.200.1"
MAC_ROUTER_CLIENT_NS="fa:16:3e:00:00:03"
# Client netns params
CLIENT_NS_NAME="client"
CLIENT_NS_CIDR="192.168.200.0/24"
IP_CLIENT_NS="192.168.200.2"
MAC_CLIENT_NS="fa:16:3e:00:00:04"


create_netns() {
    nsname="$1"
    ip="$2"
    mac="$3"
    int_iface_name="${nsname}int"
    ext_iface_name="${nsname}ext"

    # Create netns
    $IP netns add "$nsname"
    # Add veth pairs for main netns <-> created netns
    $IP link add "$int_iface_name" type veth peer name "$ext_iface_name"
    $IP link set "$ext_iface_name" up
    # Add internal iface to netns
    $IP link set "$int_iface_name" netns "$nsname"
    $IP netns exec "$nsname" ip link set lo up
    $IP netns exec "$nsname" ip link set "$int_iface_name" address "$mac"
    $IP netns exec "$nsname" ip link set "$int_iface_name" up
    $IP netns exec "$nsname" ip address add "$ip" dev "$int_iface_name"
}


delete_netns() {
    nsname="$1"
    ext_iface_name="${nsname}ext"

    $IP link delete "$ext_iface_name" 2>/dev/null || true
    $IP netns delete "$nsname"
}


create() {
    lock
    log "Create test lab"

    log "Create router netns=$ROUTER_NS_NAME ip=$IP_ROUTER_MAIN_NS mac=$MAC_ROUTER_MAIN_NS"
    create_netns "$ROUTER_NS_NAME" "${IP_ROUTER_MAIN_NS}/24" "$MAC_ROUTER_MAIN_NS"

    ext_iface_name="${ROUTER_NS_NAME}ext"
    log "Setup iface=$ext_iface_name ip=$IP_MAIN_NS mac=$MAC_MAIN_NS in main netns"
    $IP link set "$ext_iface_name" address "$MAC_MAIN_NS"
    $IP address add "$IP_MAIN_NS/24" dev "$ext_iface_name"
    $IP route add "$CLIENT_NS_CIDR" via "$IP_ROUTER_MAIN_NS"

    router_to_client_iface="${CLIENT_NS_NAME}ext"
    log "Create client netns=$CLIENT_NS_NAME ip=$IP_CLIENT_NS mac=$MAC_CLIENT_NS"
    create_netns "$CLIENT_NS_NAME" "${IP_CLIENT_NS}/24" "$MAC_CLIENT_NS"

    # Move client ext iface to router
    $IP link set "$router_to_client_iface" netns "$ROUTER_NS_NAME"
    $IP netns exec "$ROUTER_NS_NAME" ip link set "$router_to_client_iface" address "$MAC_ROUTER_CLIENT_NS"
    $IP netns exec "$ROUTER_NS_NAME" ip link set "$router_to_client_iface" up
    $IP netns exec "$ROUTER_NS_NAME" ip address add "$IP_ROUTER_CLIENT_NS/24" dev "$router_to_client_iface"
    $IP netns exec "$ROUTER_NS_NAME" sysctl -w "net.ipv4.ip_forward=1"
}


delete() {
    log "Delete test lab"

    log "Delete netns=$ROUTER_NS_NAME"
    delete_netns "$ROUTER_NS_NAME" || true
    log "Delete netns=$CLIENT_NS_NAME"
    delete_netns "$CLIENT_NS_NAME" || true

    unlock
}


lab_test() {
    log "Run connectivity test in lab"

    # Check connectivity
    if [ -z "$DEBUG" ]; then
        ping -c 1 "$IP_CLIENT_NS" -W 0.5 && log "Test result: Success" || log "Test result: Failed" "ERROR"
    else
        echo "ping -c 1 $IP_CLIENT_NS -W 0.5"
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
        Need successfull ping $IP_CLIENT_NS

        Tools to look at:
        - ip route (add|del|get)
        "
        ;;
    *)
        log "Unknown command. Use {create|delete|test|task} [DEBUG]" "ERROR"
esac

exit 0
