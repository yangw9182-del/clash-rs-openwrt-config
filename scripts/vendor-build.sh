#!/bin/sh
# ============================================================
# vendor-build.sh - 多供应商 config 生成器
# 原理: 每个供应商有独立节点文件(vendors/<name>.list), 只有"激活"供应商的
#       节点才写进 config.yaml → 未激活供应商节点零内存零CPU
# 白名单/DNS/rules: 从当前 config 保留(geosite社区+自学习实时注入不丢)
# 用法:
#   vendor-build.sh <name> [--dry-run]
#     <name> = airport|aladdin  切换并重建
#     无参数 = 用当前激活供应商重建
#     --dry-run = 只生成 config.yaml.new 不应用不重启
# ============================================================
VENDOR_DIR=/etc/clash-rs/vendors
CONFIG=/etc/clash-rs/config.yaml
ACTIVE_FILE=$VENDOR_DIR/active
MODE="${1:-}"
DRY="${2:-}"

# 切换供应商(持久)
if [ -n "$MODE" ] && [ "$MODE" != "--dry-run" ]; then
    [ -f "$VENDOR_DIR/$MODE.list" ] || { echo "供应商 $MODE 不存在"; exit 1; }
    echo "$MODE" > "$ACTIVE_FILE"
fi
ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo airport)
LIST=$VENDOR_DIR/$ACTIVE.list
[ -f "$LIST" ] || { echo "供应商 $ACTIVE 无节点列表 $LIST"; exit 1; }

# 从当前 config 提取 header(到 proxies 前, 含 dns+fake-ip-filter白名单) 和 rules
if [ ! -f "$CONFIG" ]; then echo "缺当前 config"; exit 1; fi
HEADER=$(sed -n '1,/^proxies:/p' "$CONFIG" | sed '$d')
RULES=$(sed -n '/^rules:/,$p' "$CONFIG")

# 生成: header + 激活供应商节点 + proxy-groups + rules
{
    echo "$HEADER"
    echo ""
    echo "proxies:"
    cat "$LIST"
    echo ""
    echo "proxy-groups:"
    echo "  - name: PROXY"
    echo "    type: select"
    echo "    proxies:"
    echo "      - AUTO"
    echo "      - DIRECT"
    grep -oE 'name: "[^"]+"' "$LIST" | sed 's/name: "/      - "/'
    echo ""
    echo "  - name: AUTO"
    echo "    type: url-test"
    echo "    url: http://cp.cloudflare.com/generate_204"
    echo "    interval: 600"
    echo "    tolerance: 100"
    echo "    timeout: 5"
    echo "    proxies:"
    grep -oE 'name: "[^"]+"' "$LIST" | sed 's/name: "/      - "/'
    echo ""
    echo "$RULES"
} > "$CONFIG.new"

# 校验
if ! /etc/clash-rs/clash-rs -t -f "$CONFIG.new" >/dev/null 2>&1; then
    echo "config 校验失败, 保留原配置"
    rm -f "$CONFIG.new"
    exit 1
fi
NCNT=$(grep -cE 'name: "[^"]+"' "$LIST")
if [ "$DRY" = "--dry-run" ] || [ "$MODE" = "--dry-run" ]; then
    echo "dry-run OK: $(wc -l < $CONFIG.new)行, $ACTIVE $NCNT 节点"
    exit 0
fi

mv "$CONFIG.new" "$CONFIG"
echo "已切换供应商: $ACTIVE ($NCNT 节点)"
/etc/init.d/clash-rs restart >/dev/null 2>&1 &
echo "clash-rs 重启中..."
