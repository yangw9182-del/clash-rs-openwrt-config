#!/bin/sh
# ============================================================
# vendor-watch.sh - 面板供应商切换检测
# 用户在代理面板(mihomo API /proxies/VENDOR)点选供应商,
# 本脚本(每30秒cron, flock防重入)检测选择变化 → 自动 cc vendor switch
# 切换后旧供应商节点冻结(不写进config=零内存/CPU), 不触发节点更新
# ============================================================
VENDOR_DIR=/etc/clash-rs/vendors
ACTIVE_FILE=$VENDOR_DIR/active
LOCK=/tmp/vendor-watch.lock
LOG=/tmp/vendor-watch.log

# flock 防重入
exec 9>"$LOCK"
flock -n 9 || exit 0

# 面板当前 VENDOR 组选中项 (select 组 now = 选中的成员名)
NOW=$(curl -s -m 3 -H 'Authorization: Bearer clashrs2026' \
    'http://127.0.0.1:9090/proxies/VENDOR' 2>/dev/null \
    | sed -n 's/.*"now":"\([^"]*\)".*/\1/p' | head -1)
[ -z "$NOW" ] && exit 0

ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo airport)

# 变化 → 切换(面板选中项 与 active 不一致时)
if [ "$NOW" != "$ACTIVE" ]; then
    # 校验该供应商存在
    [ -f "$VENDOR_DIR/$NOW.list" ] || exit 0
    echo "$(date '+%F %T') 面板切换: $ACTIVE -> $NOW" >> "$LOG"
    cc vendor switch "$NOW" >> "$LOG" 2>&1
fi
exit 0
