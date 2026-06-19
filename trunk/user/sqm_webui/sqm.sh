#!/bin/sh

if [ "" = "$1" ] || [ "" = "$2" ]; then
    echo "Usage:" 
    echo "$0 [Interface] clear"
    echo "$0 [Interface] [Download Mbps] [Upload Mbps]"
    exit 1
fi

WAN_INTF="$1"
# Sử dụng trực tiếp ifb0 mặc định để đảm bảo tương thích 100% với kernel Padavan
WAN_IFB="ifb0"
TC=/bin/tc
IP=/bin/ip

# Dọn dẹp cấu hình cũ
$TC qdisc del dev $WAN_INTF root >/dev/null 2>&1
$TC qdisc del dev $WAN_INTF ingress >/dev/null 2>&1
$TC qdisc del dev $WAN_IFB root >/dev/null 2>&1

if [ "$2" = "clear" ] ; then exit 0; fi

# Tự động nạp các module cần thiết
/sbin/rmmod hw_nat 2>/dev/null
/sbin/modprobe ifb numifbs=1
/sbin/modprobe sch_ingress
/sbin/modprobe sch_htb
/sbin/modprobe sch_fq_codel
/sbin/modprobe act_mirred
/sbin/modprobe cls_u32

# Quy đổi đơn vị Mbps từ tham số đầu vào sang bps (Ví dụ: 150 Mbps -> 150000000 bps)
WAN_UP_SPEED=$(( $3 * 1000000 ))
WAN_DOWN_SPEED=$(( $2 * 1000000 ))

# Cấu hình FQ_CoDel tối ưu cho băng thông cao (>100 Mbps)
TQDISC=fq_codel
FQ_CODEL_TARGET_UP="5ms"
FQ_CODEL_TARGET_DOWN="5ms"

# Ở tốc độ cao, giữ nguyên quantum mặc định của hệ thống (1514) để tránh quá tải CPU MT7621
TQDISC_OPTS_UP="target $FQ_CODEL_TARGET_UP"
TQDISC_OPTS_DOWN="target $FQ_CODEL_TARGET_DOWN"

HTB_QUANTUM_UP=1500
HTB_QUANTUM_DOWN=1500

# 1. Định hình chiều UPLOAD (Egress trên giao diện WAN/apclii0)
$TC qdisc add dev $WAN_INTF root handle 1: htb default 10
$TC class add dev $WAN_INTF parent 1: classid 1:1 htb quantum $HTB_QUANTUM_UP rate $WAN_UP_SPEED ceil $WAN_UP_SPEED
$TC class add dev $WAN_INTF parent 1:1 classid 1:10 htb quantum $HTB_QUANTUM_UP rate $WAN_UP_SPEED ceil $WAN_UP_SPEED
$TC qdisc add dev $WAN_INTF parent 1:10 handle 100: $TQDISC $TQDISC_OPTS_UP

# 2. Định hình chiều DOWNLOAD (Ingress chuyển hướng qua ifb0)
$IP link set $WAN_IFB up >/dev/null 2>&1
$TC qdisc add dev $WAN_IFB root handle 1: htb default 10
$TC class add dev $WAN_IFB parent 1: classid 1:1 htb quantum $HTB_QUANTUM_DOWN rate $WAN_DOWN_SPEED ceil $WAN_DOWN_SPEED
$TC class add dev $WAN_IFB parent 1:1 classid 1:10 htb quantum $HTB_QUANTUM_DOWN rate $WAN_DOWN_SPEED ceil $WAN_DOWN_SPEED
$TC qdisc add dev $WAN_IFB parent 1:10 handle 100: $TQDISC $TQDISC_OPTS_DOWN

# Kích hoạt chuyển hướng dữ liệu tải xuống sang ifb0
$TC qdisc add dev $WAN_INTF handle ffff: ingress
$TC filter add dev $WAN_INTF parent ffff: protocol all prio 10 u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev $WAN_IFB
