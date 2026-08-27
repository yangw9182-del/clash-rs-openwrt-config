#!/bin/sh
# ============================================================
# tolerance-config.sh - AUTO 组自适应降级 配置工具
# 用法: cc tolerance          进入交互式菜单
#       cc tolerance status   查看当前状态
#       cc tolerance reset    恢复默认设置
# ============================================================

CONF=/etc/clash-rs/tolerance.conf
DATA=/tmp/tune-tolerance.dat
LOG=/var/log/tune-tolerance.log

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# 读取配置
[ -f "$CONF" ] && . "$CONF"
: ${LEVEL0_COUNT:=10}  ${LEVEL0_TOLERANCE:=100}
: ${LEVEL1_COUNT:=8}   ${LEVEL1_TOLERANCE:=80}
: ${LEVEL2_COUNT:=5}   ${LEVEL2_TOLERANCE:=60}

# 读取当前运行状态
cur_tol=$(grep "tolerance" /etc/clash-rs/config.yaml 2>/dev/null | awk '{print $2}')
last_node=$(head -1 "$DATA" 2>/dev/null)
cnt=$(tail -1 "$DATA" 2>/dev/null)
[ -z "$cnt" ] && cnt=0

# 判断当前在第几级
current_level=0
[ "$cur_tol" = "$LEVEL1_TOLERANCE" ] && current_level=1
[ "$cur_tol" = "$LEVEL2_TOLERANCE" ] && current_level=2

show_status() {
    echo ""
    echo "${CYAN}===============================================${NC}"
    echo "${WHITE}    AUTO 组自适应降级 - 当前状态${NC}"
    echo "${CYAN}===============================================${NC}"
    echo ""
    echo "  ${YELLOW}当前级别:${NC} 第${current_level}级"
    echo "  ${YELLOW}当前 tolerance:${NC} ${cur_tol}ms"
    echo "  ${YELLOW}当前节点:${NC} ${last_node:-未知}"
    echo "  ${YELLOW}连续未切换:${NC} ${cnt}次"
    case $current_level in
        0) echo "  ${GREEN}状态: 正常（最宽松，不容易切换节点）${NC}" ;;
        1) echo "  ${YELLOW}状态: 第1级降级中（中等敏感）${NC}" ;;
        2) echo "  ${RED}状态: 第2级降级中（最敏感，极易切换）${NC}" ;;
    esac
    echo ""
    echo "  ${WHITE}各级参数说明：${NC}"
    echo "  ┌──────────┬──────────────────┬─────────────────────────┐"
    echo "  │ 级别     │ 连续不切换次数   │ tolerance 值（越小越敏感）│"
    echo "  ├──────────┼──────────────────┼─────────────────────────┤"
    if [ "$current_level" = 0 ]; then
        echo "  │ ${GREEN}初始状态${NC}  │ ≥${LEVEL0_COUNT}次              │ ${LEVEL0_TOLERANCE}ms                     │ ← 当前"
    else
        echo "  │ 初始状态  │ ≥${LEVEL0_COUNT}次              │ ${LEVEL0_TOLERANCE}ms                     │"
    fi
    if [ "$current_level" = 1 ]; then
        echo "  │ ${YELLOW}第1级降级${NC}  │ ≥${LEVEL1_COUNT}次               │ ${LEVEL1_TOLERANCE}ms                     │ ← 当前"
    else
        echo "  │ 第1级降级  │ ≥${LEVEL1_COUNT}次               │ ${LEVEL1_TOLERANCE}ms                     │"
    fi
    if [ "$current_level" = 2 ]; then
        echo "  │ ${RED}第2级降级${NC}  │ ≥${LEVEL2_COUNT}次               │ ${LEVEL2_TOLERANCE}ms                     │ ← 当前"
    else
        echo "  │ 第2级降级  │ ≥${LEVEL2_COUNT}次               │ ${LEVEL2_TOLERANCE}ms                     │"
    fi
    echo "  └──────────┴──────────────────┴─────────────────────────┘"
    echo ""
    echo "  ${YELLOW}工作原理：${NC}"
    echo "  · 每5分钟检测一次，如果节点一直没切换，说明当前节点"
    echo "    \"刚好够用\"，降低 tolerance 让 AUTO 更敏感"
    echo "  · 一旦节点切换了，立刻恢复最宽松的初始状态"
    echo "  · 连续${LEVEL0_COUNT}次(约${LEVEL0_COUNT}分钟)不切换 → 第1级降级"
    echo "  · 再连续${LEVEL1_COUNT}次(约${LEVEL1_COUNT}分钟)不切换 → 第2级降级"
    echo ""
}

edit_config() {
    while :; do
        clear
        show_status
        echo "${WHITE}  编辑配置 - 选择要修改的级别：${NC}"
        echo "${CYAN}  -----------------------------------------------${NC}"
        echo "  1) 初始状态"
        echo "     当前: 连续≥${LEVEL0_COUNT}次不切换 → tolerance=${LEVEL0_TOLERANCE}ms"
        echo "     说明: 最宽松状态，节点切换不频繁时用这个"
        echo ""
        echo "  2) 第1级降级"
        echo "     当前: 连续≥${LEVEL1_COUNT}次不切换 → tolerance=${LEVEL1_TOLERANCE}ms"
        echo "     说明: 比较敏感，节点较长时间没切换时启用"
        echo ""
        echo "  3) 第2级降级"
        echo "     当前: 连续≥${LEVEL2_COUNT}次不切换 → tolerance=${LEVEL2_TOLERANCE}ms"
        echo "     说明: 最敏感，节点很久没切换时启用，很容易跳到更快节点"
        echo ""
        echo "  0) 返回上级菜单"
        echo "${CYAN}  -----------------------------------------------${NC}"
        printf "  请输入编号: "
        read -r opt
        case "$opt" in
            1) _edit_level "LEVEL0" "初始状态" ;;
            2) _edit_level "LEVEL1" "第1级降级" ;;
            3) _edit_level "LEVEL2" "第2级降级" ;;
            0) break ;;
        esac
    done
}

_edit_level() {
    local prefix="$1" name="$2"
    local cur_cnt cur_tol
    eval "cur_cnt=\${${prefix}_COUNT}" 2>/dev/null
    eval "cur_tol=\${${prefix}_TOLERANCE}" 2>/dev/null
    echo ""
    echo "${YELLOW}  编辑【${name}】${NC}"
    echo ""
    echo "  当前配置: 连续≥${cur_cnt}次不切换 → tolerance=${cur_tol}ms"
    echo ""
    echo "  ${WHITE}【连续不切换次数】${NC}"
    echo "  数字越大越不容易降级（越稳定）"
    echo "  数字越小越容易降级（越敏感）"
    echo "  建议范围: 3~20次"
    printf "  输入新次数 [回车保持 ${cur_cnt}]: "
    read -r new_cnt
    [ -n "$new_cnt" ] && cur_cnt=$new_cnt
    # 校验为纯数字（防 sed 注入与 source 报错）
    case "$cur_cnt" in
        ''|*[!0-9]*) pl "${R}  无效次数: ${cur_cnt}${N}"; return 1 ;; esac

    echo ""
    echo "  ${WHITE}【tolerance 值(毫秒)】${NC}"
    echo "  数字越大越不容易切换节点（越稳定）"
    echo "  数字越小越容易切换节点（越敏感）"
    echo "  建议范围: 10~100ms"
    echo "  举例: 50ms 表示当前节点比最优节点慢 50ms 以内就不切换"
    printf "  输入新值 [回车保持 ${cur_tol}]: "
    read -r new_tol
    [ -n "$new_tol" ] && cur_tol=$new_tol
    case "$cur_tol" in
        ''|*[!0-9]*) pl "${R}  无效 tolerance: ${cur_tol}${N}"; return 1 ;; esac

    sed -i "s/^${prefix}_COUNT=.*/${prefix}_COUNT=${cur_cnt}/" "$CONF" 2>/dev/null
    sed -i "s/^${prefix}_TOLERANCE=.*/${prefix}_TOLERANCE=${cur_tol}/" "$CONF" 2>/dev/null
    echo ""
    echo "${GREEN}  ✓ 已更新【${name}】: 连续≥${cur_cnt}次不切换 → tolerance=${cur_tol}ms${NC}"
    sleep 2
}

reset_all() {
    echo ""
    echo "${YELLOW}  正在恢复默认设置...${NC}"
    cat > "$CONF" << 'CONFEOF'
LEVEL0_COUNT=10
LEVEL0_TOLERANCE=100
LEVEL1_COUNT=8
LEVEL1_TOLERANCE=80
LEVEL2_COUNT=5
LEVEL2_TOLERANCE=60
CONFEOF
    sed -i 's/    tolerance: [0-9]*/    tolerance: 100/' /etc/clash-rs/config.yaml 2>/dev/null
    /etc/init.d/clash-rs restart >/dev/null 2>&1 &
    echo "" > /tmp/tune-tolerance.dat
    echo ""
    echo "${GREEN}  ✓ 已恢复默认设置！${NC}"
    echo "  · 初始: 连续≥10次不切换 → tolerance=100ms"
    echo "  · 第1级: 连续≥8次不切换 → tolerance=80ms"
    echo "  · 第2级: 连续≥5次不切换 → tolerance=60ms"
    echo "  · clash-rs 正在重启..."
    sleep 2
}

show_log() {
    echo ""
    echo "${CYAN}===============================================${NC}"
    echo "${WHITE}  降级历史日志${NC}"
    echo "${CYAN}===============================================${NC}"
    echo ""
    if [ -s "$LOG" ]; then
        cat "$LOG" 2>/dev/null | tail -20
    else
        echo "  暂无降级记录（系统正常运行中）"
    fi
    echo ""
    echo "${YELLOW}  提示: 如果看到"降级"记录，说明节点长时间没切换，tolerance 自动降低了${NC}"
    echo "${YELLOW}  如果看到"恢复"记录，说明节点切换了，tolerance 回到了初始值${NC}"
    echo ""
}

case "${1:-menu}" in
    status)
        show_status
        ;;
    reset)
        reset_all
        ;;
    menu|"")
        while :; do
            clear
            echo "${CYAN}===============================================${NC}"
            echo "${WHITE}   AUTO 组自适应降级 - 配置工具${NC}"
            echo "${CYAN}===============================================${NC}"
            echo ""
            echo "${YELLOW}  这个工具管理 AUTO 组的「自动降级」功能：${NC}"
            echo "  当节点长时间不切换时，自动降低 tolerance 值，"
            echo "  让 AUTO 组更容易切换到更快的节点。"
            echo ""
            echo "${WHITE}  请选择操作：${NC}"
            echo "${CYAN}  -----------------------------------------------${NC}"
            echo "  1) 查看当前状态"
            echo "     显示当前降级级别、tolerance、连续未切换次数"
            echo ""
            echo "  2) 编辑各级参数"
            echo "     修改各级的「连续不切换次数」和「tolerance 值」"
            echo ""
            echo "  3) 恢复默认设置"
            echo "     还原为出厂推荐值（50ms/35ms/20ms）"
            echo ""
            echo "  4) 查看降级历史日志"
            echo "     看过去什么时候降级过、恢复过"
            echo ""
            echo "  0) 退出"
            echo "${CYAN}  -----------------------------------------------${NC}"
            printf "  请输入编号: "
            read -r opt
            case "$opt" in
                1) clear; show_status; echo ""; printf "  按回车键返回..."; read -r dummy ;;
                2) edit_config ;;
                3) reset_all ;;
                4) clear; show_log; printf "  按回车键返回..."; read -r dummy ;;
                0) break ;;
            esac
        done
        ;;
esac