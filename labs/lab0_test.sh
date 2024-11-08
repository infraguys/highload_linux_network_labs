#!/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab ai

set -ue
set -o pipefail


CMD="${1:-help}"
DEBUG="${2:-}"


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


# Binary
[ -n "$DEBUG" ] && PRECMD="echo " || PRECMD=""
IP="${PRECMD}$(which ip)"


# Lab params
NS_NAME="testns"
IP_MAIN_NS="192.168.100.1"
MAC_MAIN_NS="fa:16:3e:00:00:01"
IP_NS1="192.168.100.2"
MAC_NS1="fa:16:3e:00:00:02"


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

    $IP link delete "$ext_iface_name" || true
    $IP netns delete "$nsname"
}


create() {
    log "Create test lab"

    log "Create netns=$NS_NAME ip=$IP_NS1 mac=$MAC_NS1"
    create_netns "$NS_NAME" "${IP_NS1}/24" "$MAC_NS1"

    ext_iface_name="${NS_NAME}ext"
    log "Setup iface=$ext_iface_name ip=$IP_NS1 mac=$MAC_NS1 in main netns"
    $IP link set "$ext_iface_name" address "$MAC_MAIN_NS"
    $IP address add "$IP_MAIN_NS/24" dev "$ext_iface_name"
}


delete() {
    log "Delete test lab"

    log "Delete netns=$NS_NAME"
    delete_netns "$NS_NAME" || true
}


lab_test() {
    log "Run connectivity test in lab"

    # Check connectivity
    if [ -z "$DEBUG" ]; then
        ping -c 1 "$IP_NS1" -W 0.5 && log "Test result: Success" || log "Test result: Failed" "ERROR"
    else
        echo "ping -c 1 $IP_NS1 -W 0.5"
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
        log "Need successfull ping $IP_NS1"
        ;;
    *)
        log "Unknown command. Use {create|delete|test|task} [DEBUG]" "ERROR"
esac

exit 0
