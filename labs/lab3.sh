#!/bin/bash
# vim: tabstop=4 shiftwidth=4 softtabstop=4 expandtab ai

set -ue
set -o pipefail


CMD="${1:-create}"
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
BRIDGE_NAME="br"
NS_NAME="neighns"
IP_MAIN_NS="192.168.100.1"
MAC_MAIN_NS="fa:16:3e:00:00:01"
IP_NS1="192.168.100.2"
MAC_NS1="fa:16:3e:00:00:02"
MAIN_NS_IFACE="main2bridge"
MAIN_NS_2_BRIDGE="bridge2main"


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

    $IP link delete "$ext_iface_name"
    $IP netns delete "$nsname"
}


create() {
    log "Create test lab"

    log "Create netns=$NS_NAME ip=$IP_NS1 mac=$MAC_NS1"
    create_netns "$NS_NAME" "${IP_NS1}/24" "$MAC_NS1"
    ext_ns_iface_name="${NS_NAME}ext"

    log "Create veth $MAIN_NS_IFACE<->$MAIN_NS_2_BRIDGE in main netns"
    $IP link add "$MAIN_NS_IFACE" type veth peer name "$MAIN_NS_2_BRIDGE"
    $IP link set dev "$MAIN_NS_IFACE" up
    $IP link set dev "$MAIN_NS_2_BRIDGE" up

    log "Setup iface=$MAIN_NS_IFACE ip=$IP_MAIN_NS mac=$MAC_MAIN_NS in main netns"
    $IP link set "$MAIN_NS_IFACE" address "$MAC_MAIN_NS"
    $IP address add "$IP_MAIN_NS/24" dev "$MAIN_NS_IFACE"

    # Create bridge
    log "Setup bridge=$BRIDGE_NAME with $ext_ns_iface_name,$MAIN_NS_2_BRIDGE"
    $IP link add "$BRIDGE_NAME" type bridge
    $IP link set dev "$BRIDGE_NAME" up
    $IP link set dev "$ext_ns_iface_name" master "$BRIDGE_NAME"
    $IP link set dev "$MAIN_NS_2_BRIDGE" master "$BRIDGE_NAME"
}


delete() {
    log "Delete test lab"

    log "Delete bridge=$BRIDGE_NAME"
    ext_ns_iface_name="${NS_NAME}ext"
    $IP link set dev "$ext_ns_iface_name" nomaster
    $IP link set dev "$MAIN_NS_2_BRIDGE" nomaster
    $IP link delete "$BRIDGE_NAME"

    log "Delete veth $MAIN_NS_IFACE<->$MAIN_NS_2_BRIDGE in main netns"
    $IP link delete "$MAIN_NS_IFACE"

    log "Delete netns=$NS_NAME"
    delete_netns "$NS_NAME"
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
        create
        lab_test
        delete
        ;;
    task)
        log "Need successfull ping $IP_NS1"
        ;;
    *)
        log "Unknown command. Use {create|delete|test|task} [DEBUG]" "ERROR"
esac

exit 0