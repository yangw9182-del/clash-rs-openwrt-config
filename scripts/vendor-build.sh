#!/bin/sh
# ============================================================
# vendor-build.sh - 多供应商 config 生成器
# 面板控制: 生成 VENDOR 组(select, 成员=airport/aladdin 两个子组),
#   用户在代理面板点选 VENDOR 组切换供应商, vendor-watch 检测后自动重建
# 冻结: 只有激活供应商的节点写进 config → 未激活供应商零内存零CPU
#   未激活子组用 DIRECT 占位(内置, 零成本), 保证 VENDOR 组始终可选
# AUTO: 只包含激活供应商节点(url-test 只测激活节点)
# 白名单/DNS/rules: 从当前 config 保留(geosite社区+自学习不丢)
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
INIT="${3:-}"   # init 模式: 重启后由 init.d 调用, 恢复面板 VENDOR 组选中

# 供应商列表
VENDORS="airport aladdin"

# 切换供应商(持久, 但先记旧值, 校验通过后才真正落盘)
OLD_ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null || echo airport)
if [ -n "$MODE" ] && [ "$MODE" != "--dry-run" ]; then
    [ -f "$VENDOR_DIR/$MODE.list" ] || { echo "供应商 $MODE 不存在"; exit 1; }
fi
# ACTIVE 用目标值(切到新模式)或当前值
if [ -n "$MODE" ] && [ "$MODE" != "--dry-run" ]; then
    ACTIVE="$MODE"
else
    ACTIVE="$OLD_ACTIVE"
fi
LIST=$VENDOR_DIR/$ACTIVE.list
[ -f "$LIST" ] || { echo "供应商 $ACTIVE 无节点列表 $LIST"; exit 1; }

# 从当前 config 提取 header(到 proxies 前, 含 dns+fake-ip-filter白名单) 和 rules
if [ ! -f "$CONFIG" ]; then echo "缺当前 config"; exit 1; fi
HEADER=$(sed -n '1,/^proxies:/p' "$CONFIG" | sed '$d')
RULES=$(sed -n '/^rules:/,$p' "$CONFIG")
# 强制禁用 store-selected: 重启后 VENDOR 组默认=第一个成员=ACTIVE, 从根上消除
# 面板选择与 active 不一致导致的横跳/直连问题
HEADER=$(echo "$HEADER" | sed 's/^\(\s*store-selected:\) *true$/\1 false/')

# 激活供应商的节点名
NODES=$(grep -oE 'name: "[^"]+"' "$LIST" | sed 's/name: "//; s/"$//')

# 生成: header + 激活供应商节点 + proxy-groups(VENDOR/子组/PROXY/AUTO) + rules
{
    echo "$HEADER"
    echo ""
    echo "proxies:"
    cat "$LIST"
    echo ""
    echo "proxy-groups:"
    # ---- VENDOR 供应商选择组(面板控制, 激活的放第一=默认选中) ----
    echo "  - name: VENDOR"
    echo "    type: select"
    echo "    proxies:"
    echo "      - $ACTIVE"
    for v in $VENDORS; do
        [ "$v" = "$ACTIVE" ] && continue
        echo "      - $v"
    done
    echo ""
    # ---- 各供应商子组: 激活=真实节点, 未激活=DIRECT占位(冻结零内存) ----
    for v in $VENDORS; do
        echo "  - name: $v"
        echo "    type: select"
        echo "    proxies:"
        if [ "$v" = "$ACTIVE" ]; then
            echo "$NODES" | grep -v '^$' | sed 's/^/      - /'
        else
            echo "      - DIRECT"
        fi
        echo ""
    done
    # ---- PROXY 用户日常选择(默认 AUTO 自动策略) ----
    echo "  - name: PROXY"
    echo "    type: select"
    echo "    proxies:"
    echo "      - AUTO"
    echo "      - VENDOR"
    echo "      - DIRECT"
    echo "$NODES" | grep -v '^$' | sed 's/^/      - /'
    echo ""
    # ---- AUTO 自动策略(只测激活供应商节点) ----
    echo "  - name: AUTO"
    echo "    type: url-test"
    echo "    url: http://cp.cloudflare.com/generate_204"
    echo "    interval: 600"
    echo "    tolerance: 100"
    echo "    timeout: 5"
    echo "    proxies:"
    echo "$NODES" | grep -v '^$' | sed 's/^/      - /'
    echo ""
    echo "$RULES"
} > "$CONFIG.new"

# 校验
if ! /etc/clash-rs/clash-rs -t -f "$CONFIG.new" >/dev/null 2>&1; then
    echo "config 校验失败, 保留原配置"
    rm -f "$CONFIG.new"
    exit 1
fi
NCNT=$(echo "$NODES" | grep -c .)
if [ "$DRY" = "--dry-run" ] || [ "$MODE" = "--dry-run" ]; then
    echo "dry-run OK: $(wc -l < $CONFIG.new)行, $ACTIVE $NCNT 节点"
    exit 0
fi

# 应用前记录旧激活(供切换日志)
OLD="$OLD_ACTIVE"

# 无变化则跳过重启(保持 sub-update/init.d 的"内容无变化跳过重启"行为)
if cmp -s "$CONFIG" "$CONFIG.new" 2>/dev/null; then
    rm -f "$CONFIG.new"
    echo "config 无变化, 跳过重启 (供应商: $ACTIVE)"
    exit 0
fi

# 校验已通过: 现在才真正落盘 active(切换持久化), 保证校验失败时 active 不残留
echo "$ACTIVE" > "$ACTIVE_FILE"
mv "$CONFIG.new" "$CONFIG"
echo "供应商: $OLD -> $ACTIVE ($NCNT 节点)"
/etc/init.d/clash-rs restart >/dev/null 2>&1 &
echo "clash-rs 重启中..."
# 重启后同步面板 VENDOR 组选择 = 新 active(防 store-selected 横跳)
# 后台等待 API 就绪后 PUT /proxies/VENDOR, 使面板与 active 一致
(
    i=0
    while [ $i -lt 30 ]; do
        if curl -s -m 2 -H 'Authorization: Bearer clashrs2026' http://127.0.0.1:9090/proxies/VENDOR >/dev/null 2>&1; then
            curl -s -m 3 -X PUT -H 'Authorization: Bearer clashrs2026' \
                -d "{\"name\":\"$ACTIVE\"}" http://127.0.0.1:9090/proxies/VENDOR >/dev/null 2>&1
            break
        fi
        sleep 1; i=$((i+1))
    done

    # === 预热(方案A): 切换后并发预解析激活节点域名 + 触发AUTO测速 ===
    # 解决"切到 airport 后域名节点要现解析导致窗口期慢"的问题
    # 节点 server 为域名时, clash 重启后缓存清空, 首次连接/测速要重新解析
    (
        # 提取当前 config 里激活供应商节点(proxies段)的所有域名 server(非IP)
        DNS_SERVERS=$(sed -n '/^proxies:/,/^proxy-groups:/p' "$CONFIG" \
            | grep -oE 'server: [^,]+' | awk '{print $2}' \
            | grep -vE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
        # 并发后台解析(每个域名单独子进程, 不阻塞; 让 hickory/clash DNS 缓存预热)
        for _d in $DNS_SERVERS; do
            ( nslookup "$_d" 127.0.0.1 >/dev/null 2>&1 ) &
        done
        wait 2>/dev/null
        # 触发 AUTO 组测速(让 url-test 立刻选最优, 不等 interval 周期)
        curl -s -m 30 -H 'Authorization: Bearer clashrs2026' \
            "http://127.0.0.1:9090/group/AUTO/delay?url=http://cp.cloudflare.com/generate_204&timeout=4000" \
            >/dev/null 2>&1
    ) &
) &
exit 0
