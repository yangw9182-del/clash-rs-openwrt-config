#!/bin/sh
# ============================================================
# tune-tolerance.sh - AUTO 组 tolerance 自动降级（不重启版）
# 降级/切换时用 PATCH API 动态改 tolerance，零重启
# 切换/降级时记录节点延迟（从 history 取最后一条）
# 配置: /etc/clash-rs/tolerance.conf  日志: /var/log/tune-tolerance.log
# ============================================================

CONFIG=/etc/clash-rs/config.yaml
CONF=/etc/clash-rs/tolerance.conf
API=http://127.0.0.1:9090
AUTH="Authorization: Bearer clashrs2026"
DATA=/tmp/tune-tolerance.dat
LOG=/var/log/tune-tolerance.log
LOCK=/tmp/tune-tolerance.lock

[ -f "$LOCK" ] && [ -d /proc/$(cat "$LOCK" 2>/dev/null) ] && exit 0
echo $$ > "$LOCK"
trap "rm -f $LOCK" EXIT

[ -f "$CONF" ] && . "$CONF"
: ${LEVEL0_COUNT:=10}  ${LEVEL0_TOLERANCE:=100}
: ${LEVEL1_COUNT:=8}   ${LEVEL1_TOLERANCE:=80}
: ${LEVEL2_COUNT:=5}   ${LEVEL2_TOLERANCE:=60}

# 节点最近延迟(ms)，失败返回?
get_delay() {
    local node="$1"
    [ -z "$node" ] && { echo "?"; return; }
    local d
    d=$(curl -s $API/proxies/$node -H "$AUTH" --connect-timeout 3 2>/dev/null | grep -o '"delay":[0-9]*' | tail -1 | cut -d: -f2)
    [ -n "$d" ] && echo "$d" || echo "?"
}

now=$(curl -s $API/proxies/AUTO -H "$AUTH" --connect-timeout 3 2>/dev/null | awk -F'"' '{for(i=1;i<NF;i++){if($i~/now/)print $(i+2)}}')
[ -z "$now" ] && { rm -f $LOCK; exit 0; }

last_node=$(head -1 "$DATA" 2>/dev/null)
cnt=$(tail -1 "$DATA" 2>/dev/null)
[ -z "$cnt" ] && cnt=0

set_tolerance() {
    local new_tol="$1"
    curl -s -X PATCH $API/configs -H "$AUTH" -H "Content-Type: application/json"         -d "{\"proxy-groups\":{\"AUTO\":{\"tolerance\":$new_tol}}}" --connect-timeout 5 >/dev/null 2>&1
    sed -i "s/    tolerance: [0-9]*/    tolerance: $new_tol/" "$CONFIG" 2>/dev/null
}

if [ "$now" = "$last_node" ]; then
    cnt=$((cnt + 1))
else
    # 节点切换 → 记录新旧延迟 + 恢复初始
    cnt=0
    cur=$(grep "tolerance" "$CONFIG" | awk '{print $2}')
    old_d=$(get_delay "$last_node")
    new_d=$(get_delay "$now")
    if [ "$cur" != "$LEVEL0_TOLERANCE" ] 2>/dev/null; then
        set_tolerance "$LEVEL0_TOLERANCE"
    fi
    echo "$(date): 切换 ${last_node:-?}->$now 延迟${old_d}->${new_d}ms, tolerance恢复${LEVEL0_TOLERANCE}ms" >> "$LOG"
    echo "$now" > "$DATA"; echo "0" >> "$DATA"
    rm -f $LOCK; exit 0
fi

cur_tol=$(grep "tolerance" "$CONFIG" | awk '{print $2}')
current_level=0
[ "$cur_tol" = "$LEVEL1_TOLERANCE" ] && current_level=1
[ "$cur_tol" = "$LEVEL2_TOLERANCE" ] && current_level=2

next_level=$((current_level + 1))
case $next_level in
    1) target_cnt=$LEVEL1_COUNT; target_tol=$LEVEL1_TOLERANCE ;;
    2) target_cnt=$LEVEL2_COUNT; target_tol=$LEVEL2_TOLERANCE ;;
    *) target_cnt=999; target_tol=$cur_tol ;;
esac

if [ "$cnt" -ge "${target_cnt:-999}" ] 2>/dev/null && [ "$next_level" -le 2 ]; then
    cur_d=$(get_delay "$now")
    set_tolerance "$target_tol"
    echo "$(date): 降级 ${cnt}次未切换, $now延迟${cur_d}ms, tolerance ${cur_tol}->${target_tol}ms" >> "$LOG"
    echo "$now" > "$DATA"; echo "0" >> "$DATA"
    rm -f $LOCK; exit 0
fi

echo "$now" > "$DATA"; echo "$cnt" >> "$DATA"
rm -f $LOCK
