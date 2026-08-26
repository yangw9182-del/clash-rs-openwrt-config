#!/bin/sh
# Runtime network/WiFi tuning for DSG-AX3000 + clash-rs. Safe to rerun.
# Backups live in /etc/clash-rs/backups/.

# Keep CPUs at maximum frequency; proxy encryption is CPU-bound on WiFi tests.
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [ -f "$f" ] && echo performance > "$f" 2>/dev/null || true
done

# Forwarding and TCP buffer tuning: enough headroom for proxy throughput without
# turning the 171MB router into a memory balloon.
# sysctl -w net.core.netdev_max_backlog=8192 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.netdev_budget=600 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.netdev_budget_usecs=8000 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.rmem_max=16777216 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.wmem_max=16777216 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.rmem_default=262144 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.wmem_default=262144 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_rmem='4096 262144 16777216' >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_wmem='4096 262144 16777216' >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_mtu_probing=1 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_slow_start_after_idle=0 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_fastopen=3 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.ipv4.tcp_low_latency=1 >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)
# sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1 || true (已统一到 /etc/sysctl.conf)

# Avoid very deep wireless driver queues that inflate latency during proxy tests.
for ifc in ath0 ath1 wifi0 wifi1 eth0 eth1; do
  [ -e /sys/class/net/$ifc/tx_queue_len ] || continue
  case "$ifc" in
    wifi0|wifi1) echo 1500 > /sys/class/net/$ifc/tx_queue_len 2>/dev/null || true ;;
    *) echo 1000 > /sys/class/net/$ifc/tx_queue_len 2>/dev/null || true ;;
  esac
done

# Spread heavy WiFi/NSS IRQ work across the two ARM cores where the kernel allows it.
# mask 1=CPU0, 2=CPU1, 3=both.
for irq in 38 39 67 76 115 116 117 123; do
  [ -f /proc/irq/$irq/smp_affinity ] && echo 2 > /proc/irq/$irq/smp_affinity 2>/dev/null || true
done
[ -f /proc/irq/91/smp_affinity ] && echo 1 > /proc/irq/91/smp_affinity 2>/dev/null || true
[ -f /proc/irq/92/smp_affinity ] && echo 2 > /proc/irq/92/smp_affinity 2>/dev/null || true

exit 0
