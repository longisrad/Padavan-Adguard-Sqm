#!/bin/sh

if [ "" = "$1" ] || [ "" = "$2" ]; then
    echo "Usage:"
    echo "$0 [Interface] clear"
    echo "$0 [Interface] [Download kbps] [Upload kbps]"
    exit 1
fi

WAN_INTF="$1"
# Sử dụng ifb0 mặc định thay vì tạo tên tùy chỉnh để tránh lỗi kernel cũ
WAN_IFB="ifb0" 
TC=/bin/tc
IP=/bin/ip

# Xóa các hàng đợi cũ để tránh xung đột
$TC qdisc del dev $WAN_INTF root    >/dev/null 2>&1
$TC qdisc del dev $WAN_INTF ingress >/dev/null 2>&1
$TC qdisc del dev $WAN_IFB  root    >/dev/null 2>&1

if [ "$2" = "clear" ]; then exit 0; fi

# Nạp các kernel module cần thiết
/sbin/rmmod hw_nat 2>/dev/null
/sbin/modprobe ifb numifbs=1
/sbin/modprobe sch_ingress
/sbin/modprobe sch_hfsc
/sbin/modprobe sch_fq_codel
/sbin/modprobe act_mirred
/sbin/modprobe cls_u32

# kbps -> bps (HFSC tính toán chính xác hơn với đơn vị bps)
DOWN=$(( $2 * 1000 ))
UP=$(( $3 * 1000 ))

# Bóp băng thông tại 95% để giữ hàng đợi luôn nằm trên router của bạn
UP_SHAPED=$(( $UP * 95 / 100 ))
DOWN_SHAPED=$(( $DOWN * 95 / 100 ))

# Chia 3 lớp ưu tiên (Realtime, Best-Effort, Bulk)
UP_RT=$(( $UP_SHAPED / 10 ))
UP_BE=$(( $UP_SHAPED * 85 / 100 ))
UP_BK=$(( $UP_SHAPED * 5 / 100 ))

DOWN_RT=$(( $DOWN_SHAPED / 10 ))
DOWN_BE=$(( $DOWN_SHAPED * 85 / 100 ))
DOWN_BK=$(( $DOWN_SHAPED * 5 / 100 ))

QUANTUM=1514

setup_shaping() {
    DEV=$1
    RATE_TOTAL=$2
    RATE_RT=$3
    RATE_BE=$4
    RATE_BK=$5

    # Đảm bảo interface ở trạng thái hoạt động (UP)
    $IP link set dev $DEV up >/dev/null 2>&1

    $TC qdisc add dev $DEV root handle 1: hfsc default 12
    $TC class add dev $DEV parent 1:  classid 1:1  hfsc sc rate ${RATE_TOTAL} ul rate ${RATE_TOTAL}

    # Tier 1 - Realtime: VoIP, gaming
    $TC class add dev $DEV parent 1:1 classid 1:11 hfsc rt m2 ${RATE_RT} ls m2 ${RATE_RT} ul rate ${RATE_TOTAL}
    $TC qdisc add dev $DEV parent 1:11 handle 110: fq_codel quantum $QUANTUM target 5ms interval 100ms

    # Tier 2 - Normal: web, stream (mặc định)
    $TC class add dev $DEV parent 1:1 classid 1:12 hfsc ls m2 ${RATE_BE} ul rate ${RATE_TOTAL}
    $TC qdisc add dev $DEV parent 1:12 handle 120: fq_codel quantum $QUANTUM target 5ms interval 100ms

    # Tier 3 - Bulk: torrent, backup
    $TC class add dev $DEV parent 1:1 classid 1:13 hfsc ls m2 ${RATE_BK} ul rate ${RATE_TOTAL}
    $TC qdisc add dev $DEV parent 1:13 handle 130: fq_codel quantum $QUANTUM target 15ms interval 200ms

    # Phân loại DSCP -> Realtime tier
    $TC filter add dev $DEV parent 1: protocol ip prio 1 u32 \
        match ip dsfield 0xb8 0xfc flowid 1:11
    $TC filter add dev $DEV parent 1: protocol ip prio 2 u32 \
        match ip dsfield 0xa0 0xe0 flowid 1:11
    $TC filter add dev $DEV parent 1: protocol ip prio 3 u32 \
        match ip dsfield 0xc0 0xe0 flowid 1:11

    # Phân loại Bulk tier - torrent + CS1
    $TC filter add dev $DEV parent 1: protocol ip prio 8 u32 \
        match ip dsfield 0x20 0xe0 flowid 1:13
    $TC filter add dev $DEV parent 1: protocol ip prio 9 u32 \
        match ip dport 6881 0xffff flowid 1:13
    $TC filter add dev $DEV parent 1: protocol ip prio 10 u32 \
        match ip sport 6881 0xffff flowid 1:13
}

# 1. Định hình chiều Upload (egress trực tiếp trên apclii0)
setup_shaping $WAN_INTF $UP_SHAPED $UP_RT $UP_BE $UP_BK

# 2. Định hình chiều Download (chuyển hướng ingress của apclii0 sang card ảo ifb0)
$IP link set $WAN_IFB up >/dev/null 2>&1
$TC qdisc add dev $WAN_INTF handle ffff: ingress
$TC filter add dev $WAN_INTF parent ffff: protocol all prio 10 \
    u32 match u32 0 0 flowid 1:1 \
    action mirred egress redirect dev $WAN_IFB

setup_shaping $WAN_IFB $DOWN_SHAPED $DOWN_RT $DOWN_BE $DOWN_BK
