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
    if [ -z "$(which ovs-vsctl)" ]; then
        log "Need install openvswitch" "ERROR"
        exit 1
    fi
    if [[ "$(whoami)" != "root" && ! "$DEBUG" ]]; then
        log "Please run as root" "ERROR"
        exit 1
    fi
}


# Binary
[ -n "$DEBUG" ] && PRECMD="echo " || PRECMD=""
OVSVSCTL="${PRECMD}$(which ovs-vsctl)"
OVSOFCTL="${PRECMD}$(which ovs-ofctl)"
IP="${PRECMD}$(which ip)"
RM="${PRECMD}$(which rm)"


FLOW_CACHE_FILE="/tmp/flow_cache_file"

# Lab params
BRIDGE_NAME="br-test"
NS_NAME="neighns"
IP_MAIN_NS="192.168.100.1"
MAC_MAIN_NS="fa:16:3e:00:00:01"
IP_NS1="192.168.100.2"
MAC_NS1="fa:16:3e:00:00:02"
MAIN_NS_IFACE="main2bridge"
MAIN_NS_2_BRIDGE="bridge2main"
EXT_PATCH_PORT="5"
MAIN_PATCH_PORT="1"


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
    ext_ns_iface_name="${NS_NAME}ext"

    log "Create veth $MAIN_NS_IFACE<->$MAIN_NS_2_BRIDGE in main netns"
    $IP link add "$MAIN_NS_IFACE" type veth peer name "$MAIN_NS_2_BRIDGE"
    $IP link set dev "$MAIN_NS_IFACE" up
    $IP link set dev "$MAIN_NS_2_BRIDGE" up

    log "Setup iface=$MAIN_NS_IFACE ip=$IP_MAIN_NS mac=$MAC_MAIN_NS in main netns"
    $IP link set "$MAIN_NS_IFACE" address "$MAC_MAIN_NS"
    $IP address add "$IP_MAIN_NS/24" dev "$MAIN_NS_IFACE"

    log "Create ovs bridge $BRIDGE_NAME"
    $OVSVSCTL --may-exist add-br "$BRIDGE_NAME" -- set Bridge "$BRIDGE_NAME" protocols="[OpenFlow13]"
    $OVSVSCTL add-port "$BRIDGE_NAME" "$ext_ns_iface_name" -- set Interface "$ext_ns_iface_name" ofport_request="$EXT_PATCH_PORT"
    $OVSVSCTL add-port "$BRIDGE_NAME" "$MAIN_NS_2_BRIDGE" -- set Interface "$MAIN_NS_2_BRIDGE" ofport_request="$MAIN_PATCH_PORT"

    # Create flows for switch and write to $FLOW_CACHE_FILE
    flows="
    # Traffic from netns
    table=0,priority=5,in_port=${MAIN_NS_2_BRIDGE} action=output:${ext_ns_iface_name}
    table=0,priority=5,in_port=${ext_ns_iface_name} action=output:${ext_ns_iface_name}

    # Default drop flow, for packet counters
    table=0,priority=0 actions=drop
    "

    if [ -z "$DEBUG" ]; then
        # Remove comments, spaces and empty lines from flows
        echo "$flows" | sed 's/^ *//g;s/ *$//g' | grep -v '^#' | grep -v "^$" > "$FLOW_CACHE_FILE"
        chmod 644 "$FLOW_CACHE_FILE"
    else
        log "Flows for install: $flows"
    fi

    # Replace all flows in switch
    log "Add flows to $BRIDGE_NAME"
    $OVSOFCTL -O OpenFlow13 replace-flows "$BRIDGE_NAME" "$FLOW_CACHE_FILE"

    log "Flows in $BRIDGE_NAME"
    $OVSOFCTL -O OpenFlow13 --no-names dump-flows "$BRIDGE_NAME"
}


delete() {
    log "Delete test lab"

    log "Delete bridge=$BRIDGE_NAME"
    $OVSVSCTL del-br "$BRIDGE_NAME" || true

    log "Delete veth $MAIN_NS_IFACE<->$MAIN_NS_2_BRIDGE in main netns"
    $IP link delete "$MAIN_NS_IFACE" || true

    log "Delete netns=$NS_NAME"
    delete_netns "$NS_NAME" || true

    log "Delete file with flows $FLOW_CACHE_FILE"
    $RM "$FLOW_CACHE_FILE" || true
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
