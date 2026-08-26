#!/bin/sh
# RPS/XPS 优化 - 让网络中断分散到双核
for iface in eth0 eth1 ath0 ath1; do
    for q in 0 1 2 3; do
        echo 3 > /sys/class/net/$iface/queues/rx-$q/rps_cpus 2>/dev/null
        echo 3 > /sys/class/net/$iface/queues/tx-$q/xps_cpus 2>/dev/null
        echo 16384 > /sys/class/net/$iface/queues/rx-$q/rps_flow_cnt 2>/dev/null
    done
done
echo 32768 > /proc/sys/net/core/rps_sock_flow_entries 2>/dev/null
