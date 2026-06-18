#!/bin/sh

if [ "" == "$1" ] || [ "" == "$2" ]; then
    echo "Usage:"
    echo "$0 [Interface] clear"
    echo "$0 [Interface] [Download Speed kbps] [Upload Speed kbps]"
    exit 1
fi

# Load kernel modules — disable hw_nat để tránh conflict với SQM
/sbin/rmmod hw_nat 2>/dev/null
/sbin/modprobe ifb numifbs=1
/sbin/modprobe sch_ingress
/sbin/modprobe sch_htb
/sbin/modprobe sch_fq_codel
/sbin/modprobe act_mirred
/sbin/modprobe cls_u32

WAN_INTF="$1"
WAN_IFB="ifb_${WAN_INTF}"
TC=/bin/tc
IP=/bin/ip

# Xóa rules cũ trước
$TC qdisc del dev $WAN_INTF root    >/dev/null 2>&1
$TC qdisc del dev $WAN_INTF ingress >/dev/null 2>&1
$TC qdisc del dev $WAN_IFB  root    >/dev/null 2>&1

# Nếu chỉ clear thì thoát
if [ "$2" = "clear" ] ; then exit 0; fi

# Đơn vị NVRAM là kbps — convert sang bps cho tc
# FIX: × 1000 (không phải × 1000000)
WAN_DOWN_SPEED=$(( $2 * 1000 ))
WAN_UP_SPEED=$(( $3 * 1000 ))

# qdisc settings
TQDISC=fq_codel
FQ_CODEL_QUANTUM_UP=300
FQ_CODEL_QUANTUM_DOWN=300
FQ_CODEL_TARGET_UP=5ms
FQ_CODEL_TARGET_DOWN=5ms
HTB_QUANTUM_UP=1500
HTB_QUANTUM_DOWN=1500

# FIX: dùng += để không ghi đè
if [ "$TQDISC" = "fq_codel" ]; then
    TQDISC_OPTS_UP="quantum $FQ_CODEL_QUANTUM_UP target $FQ_CODEL_TARGET_UP"
    TQDISC_OPTS_DOWN="quantum $FQ_CODEL_QUANTUM_DOWN target $FQ_CODEL_TARGET_DOWN"
fi

# Upload shaping (egress trên WAN interface)
$TC qdisc add dev $WAN_INTF root handle 1: htb default 10
$TC class add dev $WAN_INTF parent 1:  classid 1:1  htb quantum $HTB_QUANTUM_UP rate ${WAN_UP_SPEED} ceil ${WAN_UP_SPEED}
$TC class add dev $WAN_INTF parent 1:1 classid 1:10 htb quantum $HTB_QUANTUM_UP rate ${WAN_UP_SPEED} ceil ${WAN_UP_SPEED}
$TC qdisc add dev $WAN_INTF parent 1:10 handle 100: $TQDISC $TQDISC_OPTS_UP

# Download shaping (ingress redirect qua ifb)
$IP link add $WAN_IFB type ifb >/dev/null 2>&1
$TC qdisc add dev $WAN_IFB root handle 1: htb default 10
$TC class add dev $WAN_IFB parent 1:  classid 1:1  htb quantum $HTB_QUANTUM_DOWN rate ${WAN_DOWN_SPEED} ceil ${WAN_DOWN_SPEED}
$TC class add dev $WAN_IFB parent 1:1 classid 1:10 htb quantum $HTB_QUANTUM_DOWN rate ${WAN_DOWN_SPEED} ceil ${WAN_DOWN_SPEED}
$TC qdisc add dev $WAN_IFB parent 1:10 handle 100: $TQDISC $TQDISC_OPTS_DOWN

$IP link set $WAN_IFB up
$TC qdisc add dev $WAN_INTF handle ffff: ingress
$TC filter add dev $WAN_INTF parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev $WAN_IFB
