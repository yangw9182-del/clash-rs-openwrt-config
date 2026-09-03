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
# 加固: 抓不到now(多为clash重启窗口API未就绪)记日志, 便于排查切换丢失; 不静默退出
if [ -z "$NOW" ]; then
    echo "$(date '+%F %T') WARN: 抓不到面板now(clash重启中/API未就绪), 本次跳过" >> "$LOG"
    exit 0
fi

ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo airport)

# 变化 → 切换(面板选中项 与 active 不一致时)
if [ "$NOW" != "$ACTIVE" ]; then
    # 校验该供应商存在
    [ -f "$VENDOR_DIR/$NOW.list" ] || exit 0
    echo "$(date '+%F %T') 面板切换: $ACTIVE -> $NOW" >> "$LOG"
    # 修复fd泄漏死锁: 切换前关闭fd9(释放锁+防止cc→vendor-build→init.d→clash子进程继承锁fd)
    # 否则clash进程持有锁fd → flock永远被占 → vendor-watch永远拿不到锁 → 切换失灵
    exec 9>&-
    cc vendor switch "$NOW" >> "$LOG" 2>&1
fi
exit 0
