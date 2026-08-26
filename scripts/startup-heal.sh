#!/bin/sh
# clash-rs startup self-heal - deduplicate DNS and check fallback
# Called by /etc/init.d/clash-rs before starting clash-rs

# Deduplicate dnsmasq server list
SERVERS=$(uci get dhcp.@dnsmasq[0].server 2>/dev/null)
if [ -n "$SERVERS" ]; then
    # Count occurrences
    COUNT=$(echo "$SERVERS" | wc -w)
    if [ "$COUNT" -gt 5 ]; then
        # Too many servers - deduplicate (只保留clash-rs 1053, 过滤AAAA)
        uci delete dhcp.@dnsmasq[0].server 2>/dev/null
        uci add_list dhcp.@dnsmasq[0].server='127.0.0.1#1053' 2>/dev/null
        uci commit dhcp 2>/dev/null
        echo "clash-rs-heal: deduplicated dnsmasq server list (was $COUNT, now 1)"
    fi
fi

# Check clash-rs config fallback for unreachable servers
# 只在 fallback 段删 DoH（不影响 nameserver 段的 DoH）
# 注意：如果用户手动选了 DoH/DoT 模式，不删
if grep -q 'tls://1.1.1.1:853' /etc/clash-rs/config.yaml 2>/dev/null; then
    # 当前是 DoT 模式，不删 DoH（用户主动选的）
    :
elif grep -q '1.1.1.1/dns-query' /etc/clash-rs/config.yaml 2>/dev/null; then
    # 只删 fallback 段的 DoH
    sed -i '/^  fallback:/,/^  fallback-/{/1.1.1.1\/dns-query/d}' /etc/clash-rs/config.yaml
    sed -i '/^  fallback:/,/^  fallback-/{/8.8.8.8\/dns-query/d}' /etc/clash-rs/config.yaml
    echo "clash-rs-heal: removed DoH from fallback (keeping UDP)"
fi

exit 0
