#!/bin/sh
# ============================================================
# cc - clash-rs 管理脚本 (ShellCrack风格中文交互菜单)
# 用法: cc [命令] 或直接 cc 进入菜单
# 安装: 复制到 /usr/bin/cc, chmod +x /usr/bin/cc
# ============================================================
# v4.7 (2026-08-01) 核心配置全覆盖 + 详细中文说明:
#   - 二进制probe确认clash-rs 0.10.8实际支持字段(剔除mihomo专属)
#   - 新增 cc clashconf 子菜单: external-controller/secret/external-ui/
#     external-ui-url/cors-allow-origins/mmdb/geosite/geosite-download-url/
#     routing-mark/interface/keep-alive-interval (均为config.yaml+重载生效)
#   - experimental 子菜单扩展: 新增 tcp-buffer-size / ignore-resolve-fail
#   - 修复BUG: do_dns_conf选项4将dns.listen对象({udp,tcp})当字符串改,会破坏DNS
#   - 全脚本命令/菜单补充详细中文功能说明与使用场景
#   - 主菜单 23(clash-rs核心配置) 子菜单入口
# v4.6 (2026-08-01) 批次8/9/10 核心能力全覆盖:
#   - 批次8 API: cc apiconf 查看运行时配置 / cc patch 热改字段(port/mode/ipv6/allow-lan/log-level)
#                 cc conns kill <id|all> 关连接 / cc rules [n] 规则列表
#                 cc dns-query <domain> [type] DNS解析 / cc flows [n] 流向聚合TOP
#                 cc provider list|update 订阅管理
#   - 批次9 设置: show_settings 16-20 (port/ipv6/log-level/allow-lan/experimental)
#   - 批次10 子菜单: cc tun TUN配置 / cc dns DNS配置 / cc profile 配置管理
#                   _patch_yaml_block 通用yaml块修改
#   - 主菜单 21(配置管理) / 22(API查询) 子菜单入口
# v4.5 (2026-08-01) 批次7 高级调优:
#   - cc tune 高级调优子菜单 (网络缓冲区/conntrack/CPU/优先级/MTU/内核内存)
#   - 网络缓冲区预设: 保守(256KB)/平衡(4MB)/激进(16MB) 一键切换
#   - conntrack预设: 小(16K)/中(65K)/大(131K) 一键切换
#   - CPU调度: performance/ondemand/powersave/schedutil 一键切换
#   - 进程优先级: clash-rs nice值/OOM score调整
#   - MTU设置: WAN/LAN接口MTU一键设置
#   - 内核内存: min_free_kbytes/swappiness/overcommit 可调
#   - 所有调整自动持久化到 sysctl.d + rc.local
# v4.4 (2026-08-01) 批次6 配置备份与持久化:
#   - C1: cc backup [list|restore] 配置备份/回滚 ($CLASH_DIR/backup/, 时间戳)
#   - C3: cc binver 查看二进制版本 + cc binbak [backup|restore] 二进制备份/回滚
#   - B7: show_settings 11/12 下载GeoIP/CN IP后校验文件大小和有效性
#   - C11: 健康检查参数(间隔/超时)持久化到 $CLASH_DIR/health_check_*.conf
#   - B8: 网络参数优化(选项13) 持久化到 uci 配置 (sysctl+nftvars+dnsmasq)
# v4.3 (2026-08-01) 批次5 监控增强:
#   - C7: do_monitor 新增clash实时流量速率 (API /connections差分)
#   - B6: do_conn 用awk单次解析JSON+修复chains显示+按下载量排序
#   - S5: do_monitor 清屏改滚动模式 (保留历史, 用分隔线区分)
#   - B12: do_top CPU%公式简化 (去除冗余*100/100)
#   - S3: do_speed 更新URL (CF 5MB→10MB, Google Android Studio→Chrome稳定版)
#   - 新增 _fmt_bytes 辅助函数统一字节格式化
# v4.2 (2026-08-01) 批次4 诊断增强:
#   - C2: cc doctor 一键诊断 (二进制/配置/PID/端口/DNS/iptables/内存/API/看门狗)
#   - B11: status 显示 AUTO 组当前节点及延迟
#   - C13: cc sysinfo 系统信息 (CPU/内存/磁盘/网络/NSS摘要)
#   - C12: cc nss NSS加速状态 (驱动/CPU负载/包统计/ECM/conntrack)
# v4.1 (2026-08-01) 批次3 节点管理:
#   - C4: do_test 支持 --auto/-a 测AUTO组, cc test auto; 通用 get_group_nodes/now
#   - C5: cc node list/add/del 节点增删 (备份+校验+API重载+失败回滚)
# v4.0 (2026-08-01) 傻瓜式增强:
#   - 新增版本号变量 CC_VERSION, cc version 可查
#   - 修复菜单2/4重复 (B13), 4改为"版本与信息"
#   - do_restart 增加重启验证+stop+start回退 (B10)
#   - do_flush 检查 drop_caches 可写性并提示 (B4)
#   - do_nettest 注释澄清DNS链路 (B5)
# v3.9 (2026-07-31) 同步 clash-rs v3.9:
#   - 二进制已修复 DNS(4项)+smart代理组(7项) 共11项BUG, 管理逻辑无需调整
#   - status 新增显示退避/并发环境变量 (CLASH_RS_BACKOFF_ROUNDS/CONCURRENCY)
# v3.8 (2026-07-31) 同步 clash-rs v3.8:
#   - 固定轮数退避(backoff_rounds=12) + 测延迟并发限制(concurrency=8)
# v3.2 (2026-07-31) 内存泄漏修复 + 交叉编译 + smart eviction
# ============================================================

CC_VERSION="4.7"

CLASH_DIR=/etc/clash-rs
CLASH_BIN=$CLASH_DIR/clash-rs
CONFIG=$CLASH_DIR/config.yaml
PID_FILE=/var/run/clash-rs.pid
INIT_SCRIPT=/etc/init.d/clash-rs
API_HOST="127.0.0.1"
API_PORT="9090"
SECRET="clashrs2026"
WATCHDOG_PID=/var/run/clash-watchdog.pid
BOOT_DELAY_FILE=$CLASH_DIR/boot_delay
MEM_THRESHOLD_FILE=$CLASH_DIR/mem_threshold
LOG_FILE=/var/log/clash-rs.log
WATCHDOG_LOG=/var/log/clash-watchdog.log
NODE_HEALTH_FILE=$CLASH_DIR/node_health_check
# 批次6新增: 持久化目录与文件
BACKUP_DIR=$CLASH_DIR/backup
HEALTH_INTERVAL_FILE=$CLASH_DIR/health_check_interval
HEALTH_TIMEOUT_FILE=$CLASH_DIR/health_check_timeout
# 二进制备份目录: /tmp (tmpfs, 82MB) - overlay空间不足(71MB)无法存16MB二进制
# 注意: /tmp是tmpfs, 重启后丢失. 二进制备份用于升级前备份+即时回滚, 非长期保存
BINBAK_DIR=/tmp/clash-rs-binbak

# 颜色定义
R='\033[1;31m'
G='\033[1;32m'
Y='\033[1;33m'
B='\033[1;34m'
C='\033[1;36m'
W='\033[1;37m'
N='\033[0m'

pl() { printf '%b\n' "$1"; }

line() {
    printf "${C}"
    i=0; while [ $i -lt 47 ]; do printf "-"; i=$((i+1)); done
    printf "${N}\n"
}

# 暂停等待用户确认 (防止输出被菜单覆盖)
pause_for_input() {
    printf "\n  ${Y}按回车键继续...${N}"
    read -r dummy </dev/tty
}

# ============================================================
# 辅助函数
# ============================================================

get_pid() { cat $PID_FILE 2>/dev/null; }

is_running() {
    PID=$(get_pid)
    [ -n "$PID" ] && kill -0 $PID 2>/dev/null
}

get_rss() {
    PID=$(get_pid)
    if [ -n "$PID" ]; then
        cat /proc/$PID/status 2>/dev/null | grep -w VmRSS | awk '{printf "%.1f", $2/1024}'
    else
        echo "0"
    fi
}

get_vmsize() {
    PID=$(get_pid)
    if [ -n "$PID" ]; then
        cat /proc/$PID/status 2>/dev/null | grep -w VmSize | awk '{printf "%.1f", $2/1024}'
    else
        echo "0"
    fi
}

get_uptime() {
    PID=$(get_pid)
    if [ -z "$PID" ]; then echo ""; return; fi
    start_time=$(cat /var/run/clash_start_time 2>/dev/null)
    if [ -n "$start_time" ]; then
        elapsed=$(($(date +%s) - start_time))
        day=$((elapsed / 86400))
        hour=$(( (elapsed % 86400) / 3600 ))
        min=$(( (elapsed % 3600) / 60 ))
        sec=$((elapsed % 60))
        [ "$day" -gt 0 ] && printf "%d天" $day
        printf "%02d:%02d:%02d" $hour $min $sec
    else
        echo "未知"
    fi
}

get_mem_threshold_mb() {
    if [ -f "$MEM_THRESHOLD_FILE" ]; then
        val=$(cat $MEM_THRESHOLD_FILE 2>/dev/null)
        if [ "$val" -gt 0 ] 2>/dev/null; then
            echo "$((val / 1024))"
            return
        fi
    fi
    echo "0"
}

# 健康检查间隔(秒) 默认300, 可通过 $HEALTH_INTERVAL_FILE 持久化
get_health_interval() {
    local v=""
    [ -f "$HEALTH_INTERVAL_FILE" ] && v=$(cat $HEALTH_INTERVAL_FILE 2>/dev/null)
    [ "$v" -ge 30 ] 2>/dev/null && { echo "$v"; return; }
    echo "300"
}

# 健康检查超时(秒) 默认5, 可通过 $HEALTH_TIMEOUT_FILE 持久化
get_health_timeout() {
    local v=""
    [ -f "$HEALTH_TIMEOUT_FILE" ] && v=$(cat $HEALTH_TIMEOUT_FILE 2>/dev/null)
    [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 30 ] 2>/dev/null && { echo "$v"; return; }
    echo "5"
}

# 字节数格式化 (B/KB/MB) - 用于流量显示
_fmt_bytes() {
    local b="${1:-0}"
    [ "$b" -gt 1048576 ] 2>/dev/null && { awk "BEGIN{printf \"%.1fMB\", $b/1048576}"; return; }
    [ "$b" -gt 1024 ] 2>/dev/null && { echo "$((b/1024))KB"; return; }
    echo "${b}B"
}

# ============================================================
# B8: 网络参数持久化辅助函数
#   _persist_sysctl_conf: 把所有 /proc/sys/... 写入 /etc/sysctl.d/99-clash-rs.conf
#   _persist_rc_local:    把非sysctl项(cpufreq/RPS/tx_queue_len)写入 /etc/rc.local
#   使用 BEGIN/END 标记段, 每次调用替换该段, 保留用户其它配置
# ============================================================
_persist_sysctl_conf() {
    local d=/etc/sysctl.d
    local f=$d/99-clash-rs.conf
    mkdir -p $d 2>/dev/null
    # 读取tune偏好, 决定sysctl值
    local buf=$(get_tune buffer aggressive)
    local ct=$(get_tune conntrack medium)
    local mem=$(get_tune mem balanced)
    # 解析buffer方案
    local rmax wmax tcp_r tcp_w
    case "$buf" in
        conservative) rmax=262144;  wmax=262144;  tcp_r="4096 16384 262144";   tcp_w="4096 16384 262144" ;;
        balanced)     rmax=4194304; wmax=4194304; tcp_r="4096 65536 4194304";  tcp_w="4096 65536 4194304" ;;
        aggressive|*) rmax=16777216;wmax=16777216;tcp_r="4096 87380 16777216"; tcp_w="4096 87380 16777216" ;;
    esac
    # 解析conntrack方案
    local ct_max ct_est ct_close ct_fin
    case "$ct" in
        small)  ct_max=16384;  ct_est=3600;  ct_close=30; ct_fin=30 ;;
        large)  ct_max=131072; ct_est=86400; ct_close=60; ct_fin=60 ;;
        medium|*) ct_max=65536; ct_est=7200;  ct_close=30; ct_fin=30 ;;
    esac
    # 解析内存方案
    local mfk swap oc
    case "$mem" in
        aggressive)   mfk=8192;  swap=40; oc=1 ;;
        conservative) mfk=32768; swap=10; oc=0 ;;
        balanced|*)   mfk=16384; swap=20; oc=0 ;;
    esac
    {
        echo "# ===== clash-rs BEGIN (由 cc settings 选项13 / cc tune 维护) ====="
        echo "# TCP 优化"
        echo "net.ipv4.tcp_fastopen = 3"
        echo "net.ipv4.tcp_tw_reuse = 1"
        echo "net.ipv4.tcp_fin_timeout = 15"
        echo "net.ipv4.tcp_keepalive_time = 300"
        echo "net.ipv4.tcp_keepalive_intvl = 30"
        echo "net.ipv4.tcp_keepalive_probes = 3"
        echo "net.ipv4.tcp_max_syn_backlog = 2048"
        echo "net.ipv4.tcp_syncookies = 1"
        echo "net.ipv4.tcp_sack = 1"
        echo "net.ipv4.tcp_window_scaling = 1"
        echo "net.ipv4.tcp_mtu_probing = 1"
        echo "net.ipv4.tcp_max_tw_buckets = 8192"
        echo "net.ipv4.ip_local_port_range = 1024 65535"
        echo "net.ipv4.tcp_low_latency = 1"
        echo "net.ipv4.tcp_thin_linear_timeouts = 1"
        echo "net.ipv4.tcp_max_orphans = 32768"
        echo "net.ipv4.tcp_retries2 = 8"
        echo "net.ipv4.tcp_ecn = 1"
        echo "# 网络缓冲区 (方案: $buf)"
        echo "net.ipv4.tcp_rmem = $tcp_r"
        echo "net.ipv4.tcp_wmem = $tcp_w"
        echo "net.core.rmem_max = $rmax"
        echo "net.core.wmem_max = $wmax"
        echo "net.core.rmem_default = $((rmax/16))"
        echo "net.core.wmem_default = $((wmax/16))"
        echo "# 软中断预算 + RPS"
        echo "net.core.rps_sock_flow_entries = 32768"
        echo "net.core.netdev_budget = 600"
        echo "net.core.netdev_budget_usecs = 8000"
        echo "net.core.netdev_max_backlog = 5000"
        echo "net.core.somaxconn = 2048"
        echo "# 连接跟踪 (方案: $ct)"
        echo "net.netfilter.nf_conntrack_max = $ct_max"
        echo "net.netfilter.nf_conntrack_tcp_timeout_established = $ct_est"
        echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait = $ct_close"
        echo "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = $ct_fin"
        echo "# 内核内存 (方案: $mem)"
        echo "vm.min_free_kbytes = $mfk"
        echo "vm.overcommit_memory = $oc"
        echo "vm.swappiness = $swap"
        echo "# ===== clash-rs END ====="
    } > "$f" 2>/dev/null
    if [ -s "$f" ]; then
        sysctl -p "$f" >/dev/null 2>&1
        return 0
    else
        return 1
    fi
}

_persist_rc_local() {
    local f=/etc/rc.local
    # 读取tune偏好
    local cpu_gov=$(get_tune cpu performance)
    local mtu_val=$(get_tune mtu 1500)
    local ct=$(get_tune conntrack medium)
    # conntrack hashsize
    local ct_max=65536
    [ "$ct" = "small" ] && ct_max=16384
    [ "$ct" = "large" ] && ct_max=131072
    local ct_hash=$((ct_max/4))
    # OpenWrt rc.local 通常是 #!/bin/sh -e + exit 0 结构
    # 我们把段落插在 exit 0 之前 (若存在), 否则追加
    local new_block="
# ===== clash-rs BEGIN (由 cc settings 选项13 / cc tune 维护) =====
# CPU 调度模式 ($cpu_gov)
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w \"\$cpu\" ] && echo $cpu_gov > \"\$cpu\" 2>/dev/null
done
# RPS 多核分发
for f in /sys/class/net/eth*/queues/rx-*/rps_cpus; do
    [ -w \"\$f\" ] && echo 3 > \"\$f\" 2>/dev/null
done
# WiFi 队列长度
for iface in ath0 ath1; do
    [ -d \"/sys/class/net/\$iface\" ] && echo 1000 > \"/sys/class/net/\$iface/tx_queue_len\" 2>/dev/null
done
# MTU 设置 ($mtu_val)
for iface in \$(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    [ -w \"/sys/class/net/\$iface/mtu\" ] && echo $mtu_val > \"/sys/class/net/\$iface/mtu\" 2>/dev/null
done
# nf_conntrack hashsize (不能通过 sysctl 设置, hash=max/4)
if [ -f /sys/module/nf_conntrack/parameters/hashsize ]; then
    echo $ct_hash > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null
fi
# clash-rs 进程优先级 (如果设置了tune偏好)
if [ -f /var/run/clash-rs.pid ]; then
    PID=\$(cat /var/run/clash-rs.pid 2>/dev/null)
    if [ -n \"\$PID\" ] && [ -d /proc/\$PID ]; then
        renice \$(cat /etc/clash-rs/tune_priority_nice 2>/dev/null || echo 0) \$PID 2>/dev/null
        echo \$(cat /etc/clash-rs/tune_priority_oom 2>/dev/null || echo 0) > /proc/\$PID/oom_score_adj 2>/dev/null
    fi
fi
# ===== clash-rs END =====
"
    if [ ! -f "$f" ]; then
        # 创建新的 rc.local
        {
            echo "#!/bin/sh -e"
            echo "$new_block"
            echo "exit 0"
        } > "$f" 2>/dev/null
        chmod +x "$f" 2>/dev/null
        return $?
    fi
    # 已存在: 移除旧段, 在 exit 0 之前插入新段 (若没有 exit 0, 则追加)
    # 用 awk 处理, 跳过 BEGIN..END 段所有行
    local tmp=/tmp/rc.local.$$
    if awk '
        /^# ===== clash-rs BEGIN / { in_sec=1; next }
        /^# ===== clash-rs END =====/ { in_sec=0; next }
        in_sec { next }
        { print }
    ' "$f" > "$tmp" 2>/dev/null; then
        # 在 exit 0 之前插入 (若有 exit 0)
        if grep -qx 'exit 0' "$tmp" 2>/dev/null; then
            # 把 exit 0 替换为 block + exit 0
            awk -v block="$new_block" '
                /^exit 0$/ && !done { printf "%s\n", block; done=1; print; next }
                { print }
            ' "$tmp" > "${tmp}.2" 2>/dev/null
            mv "${tmp}.2" "$tmp" 2>/dev/null
        else
            # 没有 exit 0, 直接追加
            printf '%s\n' "$new_block" >> "$tmp" 2>/dev/null
        fi
        mv "$tmp" "$f" 2>/dev/null
        chmod +x "$f" 2>/dev/null
        return 0
    else
        rm -f "$tmp" 2>/dev/null
        return 1
    fi
}

# ============================================================
# v4.5 高级调优模块 (cc tune)
#   所有调优参数通过预设方案傻瓜化切换, 自动持久化
#   偏好文件: $CLASH_DIR/tune_* (buffer/conntrack/cpu/mtu/mem)
# ============================================================

# 读取tune偏好, $1=名称(buffer/conntrack/cpu/mtu/mem), $2=默认值
get_tune() {
    local name="$1" default="$2"
    local f="$CLASH_DIR/tune_${name}"
    if [ -f "$f" ]; then
        local v=$(cat "$f" 2>/dev/null)
        [ -n "$v" ] && { echo "$v"; return; }
    fi
    echo "$default"
}

# 设置tune偏好
set_tune() {
    local name="$1" val="$2"
    echo "$val" > "$CLASH_DIR/tune_${name}" 2>/dev/null
}

do_tune() {
    local sub="${1:-}"
    case "$sub" in
        buffer)   _tune_buffer "$2" ;;
        conntrack) _tune_conntrack "$2" ;;
        cpu)      _tune_cpu "$2" ;;
        priority) _tune_priority "$2" ;;
        mtu)      _tune_mtu "$2" ;;
        mem)      _tune_kernel_mem "$2" ;;
        irq)      _tune_irq ;;
        ""|menu)  _tune_menu ;;
        *) pl "${R}  用法: cc tune [buffer|conntrack|cpu|priority|mtu|mem|irq]${N}"; return 1 ;;
    esac
}

_tune_menu() {
    while true; do
        # 读取当前调优状态
        local cur_buf=$(get_tune buffer balanced)
        local cur_ct=$(get_tune conntrack medium)
        local cur_cpu=$(get_tune cpu performance)
        local cur_mtu=$(get_tune mtu 1500)
        local cur_mem=$(get_tune mem balanced)
        # 获取当前nice值
        local cur_nice="?"
        local PID=$(get_pid)
        [ -n "$PID" ] && cur_nice=$(cat /proc/$PID/stat 2>/dev/null | awk '{print $19}')
        # 当前OOM score
        local cur_oom="?"
        [ -n "$PID" ] && cur_oom=$(cat /proc/$PID/oom_score_adj 2>/dev/null)

        printf "\n"
        line
        pl "${C}  高级调优 (底层参数傻瓜化调整)${N}"
        line
        pl "  ${W}1${N}. 网络缓冲区方案  当前: ${G}${cur_buf}${N}"
        pl "     ${Y}保守(256KB,省内存) / 平衡(4MB) / 激进(16MB,大吞吐)${N}"
        pl "  ${W}2${N}. 连接跟踪参数    当前: ${G}${cur_ct}${N}"
        pl "     ${Y}小(16K条) / 中(65K条) / 大(131K条)${N}"
        pl "  ${W}3${N}. CPU调度模式    当前: ${G}${cur_cpu}${N}"
        pl "     ${Y}performance(高性能) / ondemand(按需) / powersave(省电)${N}"
        pl "  ${W}4${N}. 进程优先级      当前: nice=${G}${cur_nice}${N} OOM=${G}${cur_oom}${N}"
        pl "     ${Y}调整clash-rs的CPU优先级和OOM保护${N}"
        pl "  ${W}5${N}. MTU设置        当前: ${G}${cur_mtu}${N}"
        pl "     ${Y}网络接口最大传输单元 (1500标准/1492 PPPoE/1400 VPN)${N}"
        pl "  ${W}6${N}. 内核内存参数    当前: ${G}${cur_mem}${N}"
        pl "     ${Y}激进(8MB) / 平衡(16MB) / 保守(32MB)${N}"
        pl "  ${W}7${N}. IRQ亲和性查看"
        pl "     ${Y}查看网卡中断绑定到哪个CPU核心${N}"
        pl "  ${W}8${N}. 一键极致性能 (全激进)"
        pl "     ${Y}缓冲区=激进 + conntrack=大 + CPU=performance + nice=-10${N}"
        pl "  ${W}9${N}. 一键省电模式 (全保守)"
        pl "     ${Y}缓冲区=保守 + conntrack=小 + CPU=powersave + nice=0${N}"
        pl ""
        pl "  ${W}0${N}. 返回上级菜单"
        printf "\n  请选择: "
        read choice
        case $choice in
            1) _tune_buffer ""; pause_for_input ;;
            2) _tune_conntrack ""; pause_for_input ;;
            3) _tune_cpu ""; pause_for_input ;;
            4) _tune_priority ""; pause_for_input ;;
            5) _tune_mtu ""; pause_for_input ;;
            6) _tune_kernel_mem ""; pause_for_input ;;
            7) _tune_irq; pause_for_input ;;
            8) _tune_preset_aggressive; pause_for_input ;;
            9) _tune_preset_conservative; pause_for_input ;;
            0) return ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# 网络缓冲区方案
# conservative: rmem/wmem_max=262144 (256KB), tcp_rmem/wmem=4K 16K 256K
# balanced:     rmem/wmem_max=4194304 (4MB),  tcp_rmem/wmem=4K 64K 4M
# aggressive:   rmem/wmem_max=16777216 (16MB), tcp_rmem/wmem=4K 87K 16M
_tune_buffer() {
    local preset="${1:-}"
    local cur=$(get_tune buffer balanced)
    if [ -z "$preset" ]; then
        pl "${C}  网络缓冲区方案${N} (当前: ${G}${cur}${N})"
        pl "  ${Y}缓冲区越大吞吐越高, 但占用内存越多${N}"
        pl ""
        pl "  ${W}1${N}. 保守  - rmem/wmem=256KB  (路由器内存<256MB推荐)"
        pl "  ${W}2${N}. 平衡  - rmem/wmem=4MB    (路由器内存128~256MB推荐)"
        pl "  ${W}3${N}. 激进  - rmem/wmem=16MB   (路由器内存>256MB, 大吞吐场景)"
        pl "  ${W}0${N}. 取消"
        printf "  请选择: "
        read choice
        case $choice in
            1) preset="conservative" ;;
            2) preset="balanced" ;;
            3) preset="aggressive" ;;
            *) pl "  已取消"; return 0 ;;
        esac
    fi
    local rmax wmax tcp_r tcp_w
    case "$preset" in
        conservative)
            rmax=262144; wmax=262144
            tcp_r="4096 16384 262144"; tcp_w="4096 16384 262144"
            ;;
        balanced)
            rmax=4194304; wmax=4194304
            tcp_r="4096 65536 4194304"; tcp_w="4096 65536 4194304"
            ;;
        aggressive)
            rmax=16777216; wmax=16777216
            tcp_r="4096 87380 16777216"; tcp_w="4096 87380 16777216"
            ;;
        *) pl "${R}  无效方案: $preset${N}"; return 1 ;;
    esac
    # 运行时生效
    echo $rmax > /proc/sys/net/core/rmem_max 2>/dev/null
    echo $wmax > /proc/sys/net/core/wmem_max 2>/dev/null
    echo $((rmax/16)) > /proc/sys/net/core/rmem_default 2>/dev/null
    echo $((wmax/16)) > /proc/sys/net/core/wmem_default 2>/dev/null
    echo "$tcp_r" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
    echo "$tcp_w" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
    # 持久化
    set_tune buffer "$preset"
    _persist_sysctl_conf
    pl "${G}  网络缓冲区已切换到: $preset${N}"
    pl "  rmem_max=$((rmax/1024))KB  wmem_max=$((wmax/1024))KB"
    pl "  tcp_rmem=[$(echo $tcp_r | tr ' ' '/')]"
    pl "  ${Y}已持久化到 /etc/sysctl.d/99-clash-rs.conf${N}"
}

# 连接跟踪方案
# small:  max=16384,  established=3600
# medium: max=65536,  established=7200
# large:  max=131072, established=86400
_tune_conntrack() {
    local preset="${1:-}"
    local cur=$(get_tune conntrack medium)
    if [ -z "$preset" ]; then
        pl "${C}  连接跟踪参数${N} (当前: ${G}${cur}${N})"
        # 显示当前实际值
        local cur_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)
        local cur_est=$(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null)
        local cur_count=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)
        pl "  当前: max=${cur_max:-?} 条, 已用=${cur_count:-?} 条, 超时=${cur_est:-?}s"
        pl "  ${Y}max越大支持的并发连接越多, 但占内存越多${N}"
        pl ""
        pl "  ${W}1${N}. 小  - max=16384  (家用, 设备<20台)"
        pl "  ${W}2${N}. 中  - max=65536  (家用, 设备20~50台)"
        pl "  ${W}3${N}. 大  - max=131072 (企业, 设备>50台, P2P/下载场景)"
        pl "  ${W}0${N}. 取消"
        printf "  请选择: "
        read choice
        case $choice in
            1) preset="small" ;;
            2) preset="medium" ;;
            3) preset="large" ;;
            *) pl "  已取消"; return 0 ;;
        esac
    fi
    local ct_max ct_est ct_close ct_fin
    case "$preset" in
        small)
            ct_max=16384; ct_est=3600; ct_close=30; ct_fin=30
            ;;
        medium)
            ct_max=65536; ct_est=7200; ct_close=30; ct_fin=30
            ;;
        large)
            ct_max=131072; ct_est=86400; ct_close=60; ct_fin=60
            ;;
        *) pl "${R}  无效方案: $preset${N}"; return 1 ;;
    esac
    # 运行时生效
    echo $ct_max > /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null
    echo $ct_est > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null
    echo $ct_close > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_close_wait 2>/dev/null
    echo $ct_fin > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_fin_wait 2>/dev/null
    # hashsize = max/4
    if [ -f /sys/module/nf_conntrack/parameters/hashsize ]; then
        echo $((ct_max/4)) > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null
    fi
    # 持久化
    set_tune conntrack "$preset"
    _persist_sysctl_conf
    _persist_rc_local
    pl "${G}  连接跟踪已切换到: $preset${N}"
    pl "  max=${ct_max} 条  established超时=${ct_est}s"
    pl "  ${Y}已持久化${N}"
}

# CPU调度模式
_tune_cpu() {
    local preset="${1:-}"
    local cur=$(get_tune cpu performance)
    # 获取当前实际的governor
    local cur_real="-"
    local first_cpu=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    [ -f "$first_cpu" ] && cur_real=$(cat "$first_cpu" 2>/dev/null)
    # 列出可用governor
    local avail=""
    [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && avail=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null)
    if [ -z "$preset" ]; then
        pl "${C}  CPU调度模式${N} (当前: ${G}${cur_real}${N})"
        pl "  可用: ${Y}${avail:-未知}${N}"
        pl "  ${Y}performance=最高频率 / ondemand=按需调频 / powersave=最低频率${N}"
        pl ""
        pl "  ${W}1${N}. performance  - 最高性能 (路由器推荐)"
        pl "  ${W}2${N}. ondemand     - 按需调频 (省电)"
        pl "  ${W}3${N}. powersave    - 省电模式"
        [ -n "$avail" ] && echo "$avail" | grep -qw schedutil && pl "  ${W}4${N}. schedutil    - 调度器驱动调频"
        pl "  ${W}0${N}. 取消"
        printf "  请选择: "
        read choice
        case $choice in
            1) preset="performance" ;;
            2) preset="ondemand" ;;
            3) preset="powersave" ;;
            4) preset="schedutil" ;;
            *) pl "  已取消"; return 0 ;;
        esac
    fi
    # 检查该governor是否可用
    if [ -n "$avail" ] && ! echo "$avail" | grep -qw "$preset"; then
        pl "${R}  CPU不支持 $preset 模式${N}"
        pl "  可用: $avail"
        return 1
    fi
    # 运行时生效
    local ok=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [ -w "$cpu" ] && echo "$preset" > "$cpu" 2>/dev/null && ok=1
    done
    if [ "$ok" = "1" ]; then
        set_tune cpu "$preset"
        _persist_rc_local
        pl "${G}  CPU调度已切换到: $preset${N}"
        # 显示当前频率
        local freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        [ -n "$freq" ] && pl "  当前频率: $((freq/1000)) MHz"
        pl "  ${Y}已持久化到 /etc/rc.local${N}"
    else
        pl "${R}  设置失败 (无可写CPU频率接口)${N}"
        return 1
    fi
}

# 进程优先级 (nice + OOM score)
_tune_priority() {
    local PID=$(get_pid)
    if [ -z "$PID" ]; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    local cur_nice=$(cat /proc/$PID/stat 2>/dev/null | awk '{print $19}')
    local cur_oom=$(cat /proc/$PID/oom_score_adj 2>/dev/null)
    pl "${C}  进程优先级${N} (PID: $PID)"
    pl "  当前: nice=${G}${cur_nice}${N}  OOM score adj=${G}${cur_oom:-?}${N}"
    pl "  ${Y}nice越低=CPU优先级越高(-20~19) / OOM越低=越不容易被杀(-1000~1000)${N}"
    pl ""
    pl "  ${W}1${N}. 高优先级  - nice=-10, OOM=-500  (clash-rs最重要)"
    pl "  ${W}2${N}. 标准优先级 - nice=0,   OOM=0    (默认)"
    pl "  ${W}3${N}. 低优先级  - nice=5,   OOM=200  (其他服务更重要)"
    pl "  ${W}4${N}. 极高优先级 - nice=-15, OOM=-1000 (几乎不被杀)"
    pl "  ${W}0${N}. 取消"
    printf "  请选择: "
    read choice
    local new_nice new_oom
    case $choice in
        1) new_nice=-10; new_oom=-500 ;;
        2) new_nice=0; new_oom=0 ;;
        3) new_nice=5; new_oom=200 ;;
        4) new_nice=-15; new_oom=-1000 ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 应用nice
    renice $new_nice $PID 2>/dev/null
    # 应用OOM score
    echo $new_oom > /proc/$PID/oom_score_adj 2>/dev/null
    pl "${G}  已设置: nice=$new_nice  OOM=$new_oom${N}"
    # 持久化: 写入init脚本的启动参数 (通过tune文件)
    set_tune priority_nice "$new_nice"
    set_tune priority_oom "$new_oom"
    pl "  ${Y}注意: 优先级在服务重启后需要重新设置${N}"
    pl "  ${Y}建议: 在 /etc/init.d/clash-rs 的start函数末尾添加:${N}"
    pl "    renice $new_nice \$(cat $PID_FILE) 2>/dev/null"
    pl "    echo $new_oom > /proc/\$(cat $PID_FILE)/oom_score_adj 2>/dev/null"
}

# MTU设置
_tune_mtu() {
    local preset="${1:-}"
    local cur=$(get_tune mtu 1500)
    # 列出网络接口
    pl "${C}  MTU设置${N} (当前偏好: ${G}${cur}${N})"
    # 显示各接口当前MTU
    pl "  当前接口MTU:"
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
        local mtu=$(cat /sys/class/net/$iface/mtu 2>/dev/null)
        [ -n "$mtu" ] && pl "    $iface: ${G}${mtu}${N}"
    done
    pl ""
    pl "  ${Y}MTU=最大传输单元, 设置错误会导致网络不通${N}"
    pl ""
    pl "  ${W}1${N}. 1500  - 标准以太网 (大多数情况推荐)"
    pl "  ${W}2${N}. 1492  - PPPoE拨号"
    pl "  ${W}3${N}. 1400  - VPN/IPIP隧道"
    pl "  ${W}4${N}. 1280  - IPv6最小MTU"
    pl "  ${W}0${N}. 取消"
    printf "  请选择: "
    read choice
    local new_mtu
    case $choice in
        1) new_mtu=1500 ;;
        2) new_mtu=1492 ;;
        3) new_mtu=1400 ;;
        4) new_mtu=1280 ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 应用到所有非lo接口
    pl "  设置MTU=$new_mtu ..."
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
        echo $new_mtu > /sys/class/net/$iface/mtu 2>/dev/null && pl "    ${G}$iface${N}: $new_mtu"
    done
    # 持久化
    set_tune mtu "$new_mtu"
    _persist_rc_local
    pl "${G}  MTU已设置为: $new_mtu${N}"
    pl "  ${Y}已持久化到 /etc/rc.local${N}"
}

# 内核内存参数
_tune_kernel_mem() {
    local preset="${1:-}"
    local cur=$(get_tune mem balanced)
    local cur_mfk=$(cat /proc/sys/vm/min_free_kbytes 2>/dev/null)
    local cur_swap=$(cat /proc/sys/vm/swappiness 2>/dev/null)
    local cur_oc=$(cat /proc/sys/vm/overcommit_memory 2>/dev/null)
    if [ -z "$preset" ]; then
        pl "${C}  内核内存参数${N} (当前: ${G}${cur}${N})"
        pl "  实际: min_free=${cur_mfk:-?}KB  swappiness=${cur_swap:-?}  overcommit=${cur_oc:-?}"
        pl "  ${Y}min_free_kbytes=内核保留内存 / swappiness=swap倾向 / overcommit=超额分配策略${N}"
        pl ""
        pl "  ${W}1${N}. 激进  - min_free=8MB,  swap=40, oc=1  (内存紧张, 最大化可用RAM, 仅剩8MB时回收)"
        pl "  ${W}2${N}. 平衡  - min_free=16MB, swap=20, oc=0  (默认推荐)"
        pl "  ${W}3${N}. 保守  - min_free=32MB, swap=10, oc=0  (大内存, 保留32MB缓冲防OOM)"
        pl "  ${W}0${N}. 取消"
        printf "  请选择: "
        read choice
        case $choice in
            1) preset="aggressive" ;;
            2) preset="balanced" ;;
            3) preset="conservative" ;;
            *) pl "  已取消"; return 0 ;;
        esac
    fi
    local mfk swap oc
    case "$preset" in
        aggressive)   mfk=8192;  swap=40; oc=1 ;;
        balanced)     mfk=16384; swap=20; oc=0 ;;
        conservative) mfk=32768; swap=10; oc=0 ;;
        *) pl "${R}  无效方案${N}"; return 1 ;;
    esac
    echo $mfk > /proc/sys/vm/min_free_kbytes 2>/dev/null
    echo $swap > /proc/sys/vm/swappiness 2>/dev/null
    echo $oc > /proc/sys/vm/overcommit_memory 2>/dev/null
    set_tune mem "$preset"
    _persist_sysctl_conf
    pl "${G}  内核内存已切换到: $preset${N}"
    pl "  min_free_kbytes=$mfk  swappiness=$swap  overcommit=$oc"
    pl "  ${Y}已持久化${N}"
}

# IRQ亲和性查看
_tune_irq() {
    pl "${C}  IRQ亲和性 (网卡中断绑定)${N}"
    line
    # 找到网卡相关的IRQ
    local found=0
    for iface in eth0 eth1; do
        [ -d "/sys/class/net/$iface" ] || continue
        local irq=$(cat /sys/class/net/$iface/device/irq 2>/dev/null)
        if [ -n "$irq" ] && [ "$irq" != "0" ]; then
            found=1
            local smp_affinity="-"
            [ -f "/proc/irq/$irq/smp_affinity" ] && smp_affinity=$(cat /proc/irq/$irq/smp_affinity 2>/dev/null)
            local smp_affinity_list="-"
            [ -f "/proc/irq/$irq/smp_affinity_list" ] && smp_affinity_list=$(cat /proc/irq/$irq/smp_affinity_list 2>/dev/null)
            pl "  ${G}$iface${N}: IRQ=$irq  smp_affinity=${smp_affinity}  (CPU: ${smp_affinity_list})"
            # 解析smp_affinity (hex格式)
            local cpu_mask=0
            case "$smp_affinity" in
                00000001|1) cpu_mask=0 ;;
                00000002|2) cpu_mask=1 ;;
                00000003|3) cpu_mask="0,1" ;;
                *) cpu_mask="$smp_affinity" ;;
            esac
            pl "    绑定CPU: $cpu_mask"
        fi
    done
    if [ "$found" = "0" ]; then
        pl "  ${Y}未找到网卡IRQ信息 (可能使用NAPI或轮询模式)${N}"
    fi
    # 显示中断统计
    pl ""
    pl "  ${C}网卡中断统计 (TOP5):${N}"
    grep -E 'eth[01]|wifi|wireless|nss' /proc/interrupts 2>/dev/null | head -5 | while read line; do
        pl "  $line"
    done
    [ -z "$(grep -E 'eth[01]|wifi|wireless|nss' /proc/interrupts 2>/dev/null | head -1)" ] && pl "  ${Y}无相关中断记录${N}"
    # NSS相关
    pl ""
    pl "  ${C}NSS加速引擎状态:${N}"
    if ls /sys/kernel/debug/ecm* >/dev/null 2>&1 || ls /proc/ecm* >/dev/null 2>&1; then
        pl "  ${G}ECM已加载${N}"
    else
        pl "  ${Y}ECM未检测到${N}"
    fi
}

# 一键极致性能
_tune_preset_aggressive() {
    pl "${C}  一键极致性能模式${N}"
    pl "  ${Y}缓冲区=激进 + conntrack=大 + CPU=performance + nice=-10 + OOM=-500${N}"
    pl ""
    pl "  ${Y}确认应用全部激进设置? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    _tune_buffer aggressive 2>&1 | tail -1
    _tune_conntrack large 2>&1 | tail -1
    _tune_cpu performance 2>&1 | tail -1
    # 进程优先级
    local PID=$(get_pid)
    if [ -n "$PID" ]; then
        renice -10 $PID 2>/dev/null
        echo -500 > /proc/$PID/oom_score_adj 2>/dev/null
        set_tune priority_nice "-10"
        set_tune priority_oom "-500"
        pl "${G}  进程优先级: nice=-10 OOM=-500${N}"
    fi
    pl ""
    pl "${G}  ===== 一键极致性能已完成 =====${N}"
    pl "  所有设置已持久化, 重启不丢失"
}

# 一键省电模式
_tune_preset_conservative() {
    pl "${C}  一键省电模式${N}"
    pl "  ${Y}缓冲区=保守 + conntrack=小 + CPU=powersave + nice=0${N}"
    pl ""
    pl "  ${Y}确认应用全部保守设置? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    _tune_buffer conservative 2>&1 | tail -1
    _tune_conntrack small 2>&1 | tail -1
    _tune_cpu powersave 2>&1 | tail -1
    # 进程优先级
    local PID=$(get_pid)
    if [ -n "$PID" ]; then
        renice 0 $PID 2>/dev/null
        echo 0 > /proc/$PID/oom_score_adj 2>/dev/null
        set_tune priority_nice "0"
        set_tune priority_oom "0"
        pl "${G}  进程优先级: nice=0 OOM=0${N}"
    fi
    pl ""
    pl "${G}  ===== 一键省电模式已完成 =====${N}"
    pl "  所有设置已持久化, 重启不丢失"
}

api() {
    curl -s -H "Authorization: Bearer $SECRET" "http://${API_HOST}:${API_PORT}$1" 2>/dev/null
}

# URL编码函数 (busybox ash兼容, S2优化: 用shell算术替代第二次printf fork)
urlencode() {
    local str="$1" out="" c code h1 h2
    local _hex="0123456789abcdef"
    local i=0
    while [ $i -lt ${#str} ]; do
        c="${str:$i:1}"
        case "$c" in
            [a-zA-Z0-9._-]) out="$out$c" ;;
            ' ') out="$out%20" ;;
            *)
                code=$(printf '%d' "'$c" 2>/dev/null)
                if [ -n "$code" ] && [ "$code" -gt 0 ] 2>/dev/null; then
                    h1=$((code / 16))
                    h2=$((code % 16))
                    out="$out%${_hex:$h1:1}${_hex:$h2:1}"
                else
                    out="$out$c"
                fi
                ;;
        esac
        i=$((i+1))
    done
    printf '%s' "$out"
}

# 从PROXY组获取成员节点列表 (S1: 用sed替代grep -o, 更健壮)
# C4: 通用代理组节点获取/当前选择 (支持任意组名 PROXY/AUTO/...)
get_group_nodes() {
    api "/proxies/$1" 2>/dev/null | sed 's/.*"all":\[//; s/\].*//' | tr ',' '\n' | tr -d '"' | grep -v '^$'
}

get_group_now() {
    api "/proxies/$1" 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4
}

# 向后兼容: PROXY 组
get_proxy_nodes() { get_group_nodes "PROXY"; }
get_proxy_now() { get_group_now "PROXY"; }

# ============================================================
# 命令模式
# ============================================================

do_start() {
    if is_running; then
        pl "${Y}  clash-rs 已在运行 (PID:$(get_pid))${N}"
        return
    fi
    $INIT_SCRIPT start
}

do_stop() {
    if ! is_running; then
        pl "${Y}  clash-rs 未在运行${N}"
        return
    fi
    $INIT_SCRIPT stop
}

do_restart() {
    OLD_PID=$(get_pid)
    $INIT_SCRIPT restart 2>/dev/null
    sleep 1
    # 验证重启是否成功: 进程存活且PID已变化
    if ! is_running; then
        pl "${Y}  init.d restart 未生效, 回退 stop+start...${N}"
        $INIT_SCRIPT stop 2>/dev/null
        sleep 1
        $INIT_SCRIPT start
        sleep 1
    fi
    NEW_PID=$(get_pid)
    if is_running && [ -n "$NEW_PID" ] && [ "$NEW_PID" != "$OLD_PID" ]; then
        pl "${G}  重启成功, 新PID: $NEW_PID${N}"
    elif is_running; then
        pl "${Y}  服务运行中但PID未变 (PID:$NEW_PID), 可能未真正重启${N}"
    else
        pl "${R}  重启失败, 请查看日志: cc log${N}"
    fi
}

do_status() {
    if is_running; then
        PID=$(get_pid)
        RSS=$(get_rss)
        VMS=$(get_vmsize)
        UPTIME=$(get_uptime)
        PROXY=$(get_proxy_now)
        MEM_MB=$(get_mem_threshold_mb)
        HARD_MB=$((MEM_MB * 3 / 2))
        OOM=$(cat /proc/$PID/oom_score_adj 2>/dev/null)
        THREADS=$(grep Threads /proc/$PID/status 2>/dev/null | awk '{print $2}')
        pl "${G}  clash-rs 运行中${N}"
        pl "  PID: $PID  线程: ${THREADS:-?}"
        pl "  内存: ${RSS}MB / Soft限制${MEM_MB}MB / Hard限制${HARD_MB}MB"
        pl "  虚拟内存: ${VMS}MB"
        pl "  运行时间: $UPTIME"
        pl "  当前节点: ${G}${PROXY:-未知}${N}"
        # B11: AUTO组当前节点及延迟
        AUTO_NOW=$(get_group_now "AUTO" 2>/dev/null)
        if [ -n "$AUTO_NOW" ]; then
            AUTO_DELAY=$(api "/proxies/$(urlencode "$AUTO_NOW")" 2>/dev/null | grep -oE '"delay":[0-9]+' | head -1 | cut -d: -f2)
            pl "  AUTO自动选择: ${G}${AUTO_NOW}${N} 延迟: ${AUTO_DELAY:-无记录}ms"
        fi
        pl "  OOM优先级: $OOM"
        # 内存保护状态
        pl "  ${C}内存保护:${N}"
        pl "    内置管理: ${G}Soft=${MEM_MB}MB(拒新连接) Hard=${HARD_MB}MB(关旧连接)${N}"
        # 健康检查参数 (v3.8+ 环境变量)
        BACKOFF=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^CLASH_RS_BACKOFF_ROUNDS=' | cut -d= -f2)
        CONCURRENCY=$(cat /proc/$PID/environ 2>/dev/null | tr '\0' '\n' | grep '^CLASH_RS_HEALTHCHECK_CONCURRENCY=' | cut -d= -f2)
        [ -z "$BACKOFF" ] && BACKOFF="12(默认)"
        [ -z "$CONCURRENCY" ] && CONCURRENCY="8(默认)"
        pl "  ${C}健康检查:${N}"
        pl "    退避轮数: ${G}${BACKOFF}${N}  并发限制: ${G}${CONCURRENCY}${N}"
        # 端口检查 (兼容busybox: 优先ss, 回退netstat, 最后检查已知端口)
        ports=""
        if command -v ss >/dev/null 2>&1; then
            ports=$(ss -tlnp 2>/dev/null | grep "$PID" | grep -oE ':[0-9]+ ' | tr -d ': ' | sort -u | tr '\n' ' ')
        fi
        if [ -z "$ports" ] && command -v netstat >/dev/null 2>&1; then
            # busybox netstat: PID可能显示在最后一列
            ports=$(netstat -tlnp 2>/dev/null | grep "$PID" | awk '{print $4}' | grep -oE '[0-9]+$' | sort -u | tr '\n' ' ')
        fi
        if [ -z "$ports" ]; then
            # 回退: 检查clash-rs已知端口是否在监听
            for p in 7890 7892 7893 9090 1053; do
                if netstat -tln 2>/dev/null | grep -q ":$p " || ss -tln 2>/dev/null | grep -q ":$p "; then
                    ports="$ports$p "
                fi
            done
        fi
        pl "  监听端口: ${ports:-无}"
        # 看门狗状态
        if [ -f "$WATCHDOG_PID" ] && kill -0 $(cat $WATCHDOG_PID 2>/dev/null) 2>/dev/null; then
            WD_MB=$((MEM_MB * 2))
            pl "  外部看门狗: ${G}运行中${N} (PID:$(cat $WATCHDOG_PID), 2x限制=${WD_MB}MB)"
        else
            pl "  外部看门狗: ${Y}未运行${N}"
        fi
    else
        pl "${R}  clash-rs 未运行${N}"
        # 检查是否被OOM杀
        oomlog=$(dmesg 2>/dev/null | grep -i "killed.*clash-rs" | tail -1)
        if [ -n "$oomlog" ]; then
            pl "${R}  检测到OOM Killer日志:${N}"
            pl "  $oomlog"
        fi
    fi
}

# ============================================================
# 节点延迟并发测试 (B1: 替代串行, 8并发)
# stdin: 节点列表每行一个
# stdout: "delay node" 每行, 按延迟升序 (超时=99999)
# $1=并发数(默认8) $2=超时ms(默认5000)
#
# SS2022特殊处理: clash-rs 0.10.8 的 HTTP delay test 对
# SS2022 (2022-blake3-*) 协议有bug, 全部返回
# "connection closed before message completed"。
# 对SS2022节点改用TCP直连测速: curl测到SS服务器的
# TCP连接时间(time_connect), 等效于真实延迟(SS加密开销<1ms)。
# 其他协议(Trojan/AnyTLS等)仍用clash-rs API delay test。
# ============================================================
test_nodes_concurrent() {
    local concurrency="${1:-8}"
    local timeout="${2:-5000}"
    local tmpdir="/tmp/cc_delay_$$"
    mkdir -p "$tmpdir" 2>/dev/null
    local i=0
    while IFS= read -r n; do
        [ -z "$n" ] && continue
        i=$((i+1))
        (
            encoded_n=$(urlencode "$n")
            node_info=$(api "/proxies/$encoded_n" 2>/dev/null)
            node_type=$(printf '%s' "$node_info" | grep -oE '"type":"[^"]+"' | head -1 | sed 's/"type":"//;s/"//')
            delay=""
            is_ss2022=false

            # SS2022检测: type=Shadowsocks 且 cipher以2022-开头
            if [ "$node_type" = "Shadowsocks" ]; then
                node_cipher=$(printf '%s' "$node_info" | grep -oE '"cipher":"[^"]*"' | head -1 | sed 's/"cipher":"//;s/"//')
                if printf '%s' "$node_cipher" | grep -q '^2022-'; then
                    is_ss2022=true
                    server=$(printf '%s' "$node_info" | grep -oE '"server":"[^"]+"' | head -1 | sed 's/"server":"//;s/"//')
                    port=$(printf '%s' "$node_info" | grep -oE '"port":[0-9]+' | head -1 | sed 's/"port"://')
                    if [ -n "$server" ] && [ -n "$port" ]; then
                        # TCP直连测速: time_connect = TCP握手完成时间 = 真实RTT
                        # --max-time 1: TCP连接后curl会尝试发HTTP, SS服务器不响应, 1秒后退出
                        tc=$(curl -o /dev/null -s -w '%{time_connect}' --connect-timeout 3 --max-time 1 "http://$server:$port" 2>/dev/null)
                        if [ -n "$tc" ] && [ "$tc" != "0.000000" ]; then
                            delay=$(printf '%s' "$tc" | awk '{printf "%d", $1 * 1000}')
                            [ "$delay" -le 0 ] 2>/dev/null && delay=""
                        fi
                    fi
                fi
            fi

            # 非SS2022: 使用clash-rs API delay test (Trojan/AnyTLS等正常工作)
            if [ "$is_ss2022" = "false" ]; then
                delay=$(api "/proxies/$encoded_n/delay?timeout=${timeout}&url=http://www.gstatic.com/generate_204" 2>/dev/null | grep -o '"delay":[0-9]*' | cut -d: -f2)
            fi

            if [ -n "$delay" ] && [ "$delay" -gt 0 ] 2>/dev/null; then
                printf '%s %s\n' "$delay" "$n"
            else
                printf '99999 %s\n' "$n"
            fi
        ) > "$tmpdir/$i" &
        [ $((i % concurrency)) -eq 0 ] && wait
    done
    wait
    cat "$tmpdir"/* 2>/dev/null | sort -n
    rm -rf "$tmpdir" 2>/dev/null
}

# 切换到指定节点并验证 (B3: 切换后用 get_group_now 二次验证)
# $1=节点名 $2=组名(默认PROXY)
do_switch_to() {
    local target="$1"
    local group="${2:-PROXY}"
    local json_name result proxy_now
    json_name=$(printf '%s' "$target" | sed 's/\\/\\\\/g; s/"/\\"/g')
    result=$(curl -s -X PUT -H "Authorization: Bearer $SECRET" -H "Content-Type: application/json" \
        -d "{\"name\":\"$json_name\"}" "http://${API_HOST}:${API_PORT}/proxies/$group" 2>/dev/null)
    # 仅检查明显错误关键字 (clash-rs v0.10.8 成功时返回 {"message":"selected proxy X for GROUP"})
    if echo "$result" | grep -qiE 'error|not found|invalid|forbidden' 2>/dev/null; then
        pl "${R}  切换失败: $result${N}"
        return 1
    fi
    # B3: 等待1秒后用 get_group_now 验证
    sleep 1
    proxy_now=$(get_group_now "$group")
    if [ "$proxy_now" = "$target" ]; then
        pl "${G}  已切换到: $target${N}"
        return 0
    else
        pl "${Y}  切换请求已发送, 当前节点: ${proxy_now:-未知}${N}"
        pl "  (若目标为AUTO组, 显示组名属正常)"
        return 0
    fi
}

do_switch() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi

    # C14: --auto 自动选择最快节点
    # 支持 --group <组名> 指定目标组 (默认PROXY; crontab用--group AUTO)
    if [ "$1" = "--auto" ] || [ "$1" = "-a" ]; then
        local target_group="PROXY"
        if [ "$2" = "--group" ] && [ -n "$3" ]; then
            target_group="$3"
        fi
        pl "${C}  自动选择最快节点 → ${target_group}组...${N}"
        nodes=$(get_group_nodes "$target_group")
        [ -z "$nodes" ] && pl "${R}  未获取到 ${target_group} 组节点列表${N}" && return
        # 排除 AUTO 和 DIRECT (非实际节点)
        testable=$(echo "$nodes" | grep -vE '^(AUTO|DIRECT)$')
        [ -z "$testable" ] && pl "${R}  无可测试节点${N}" && return
        cnt=$(echo "$testable" | grep -c .)
        pl "  并发测试 ${cnt} 个节点 (并发8, 超时5s)..."
        best_line=$(echo "$testable" | test_nodes_concurrent 8 5000 | head -1)
        [ -z "$best_line" ] && pl "${R}  测试失败${N}" && return
        best_delay=${best_line%% *}
        best_node=${best_line#* }
        if [ "$best_delay" = "99999" ]; then
            pl "${R}  所有节点均超时, 无法自动切换${N}"
            return
        fi
        pl "  最快节点: ${G}${best_node}${N} (${best_delay}ms)"
        do_switch_to "$best_node" "$target_group"
        return
    fi

    # 交互式选择 (B2: 不测延迟, 直接列出节点)
    nodes=$(get_proxy_nodes)
    if [ -z "$nodes" ]; then
        pl "${R}  未获取到节点列表${N}"
        return
    fi
    current=$(get_proxy_now)
    pl "${C}  可用节点${N} (当前: ${G}${current:-未知}${N})"
    line
    i=0
    echo "$nodes" | while read n; do
        [ -z "$n" ] && continue
        i=$((i+1))
        if [ "$n" = "$current" ]; then
            pl "  ${G}*$i${N}. $n ${G}[当前]${N}"
        else
            pl "  $i. $n"
        fi
    done
    line
    pl "  输入编号切换 | r=测延迟排序 | a=自动选择 | 回车退出"
    printf "  > "
    read choice
    [ -z "$choice" ] && return

    case "$choice" in
        r|R)
            pl "${C}  并发测试延迟...${N}"
            echo "$nodes" | test_nodes_concurrent 8 5000 | while read d n; do
                if [ "$d" = "99999" ]; then
                    pl "  ${R}$n${N}: 超时"
                elif [ "$d" -lt 200 ] 2>/dev/null; then
                    pl "  ${G}$n${N}: ${d}ms"
                elif [ "$d" -lt 500 ] 2>/dev/null; then
                    pl "  ${Y}$n${N}: ${d}ms"
                else
                    pl "  ${R}$n${N}: ${d}ms"
                fi
            done
            pause_for_input
            ;;
        a|A)
            do_switch --auto
            pause_for_input
            ;;
        *)
            # 验证choice为正整数
            case "$choice" in
                ''|*[!0-9]*) pl "${R}  无效编号: $choice${N}"; return ;;
            esac
            selected=$(echo "$nodes" | sed -n "${choice}p")
            if [ -n "$selected" ]; then
                do_switch_to "$selected"
            else
                pl "${R}  无效选择${N}"
            fi
            ;;
    esac
}

do_test() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi
    # C4: 支持 --auto/-a 测AUTO组, 或指定组名
    local group="PROXY"
    case "$1" in
        --auto|-a|auto|AUTO) group="AUTO" ;;
        "") group="PROXY" ;;
        *) group="$1" ;;
    esac
    pl "${C}  并发测试 ${group} 组节点延迟...${N}"
    nodes=$(get_group_nodes "$group")
    if [ -z "$nodes" ]; then
        pl "${R}  未获取到 ${group} 组节点列表${N}"
        return
    fi
    current=$(get_group_now "$group")
    cnt=$(echo "$nodes" | grep -c .)
    pl "  共 ${cnt} 个节点, 并发8, 超时5s  (当前: ${G}${current:-未知}${N})"
    pl ""
    echo "$nodes" | test_nodes_concurrent 8 5000 | while read d n; do
        mark=""
        [ "$n" = "$current" ] && mark=" ${G}[当前]${N}"
        if [ "$d" = "99999" ]; then
            pl "  ${R}$n${N}: 超时${mark}"
        elif [ "$d" -lt 200 ] 2>/dev/null; then
            pl "  ${G}$n${N}: ${d}ms${mark}"
        elif [ "$d" -lt 500 ] 2>/dev/null; then
            pl "  ${Y}$n${N}: ${d}ms${mark}"
        else
            pl "  ${R}$n${N}: ${d}ms${mark}"
        fi
    done
    # AUTO组额外显示自动选择结果
    if [ "$group" = "AUTO" ]; then
        auto_now=$(get_group_now "AUTO")
        pl ""
        pl "  ${C}AUTO 自动选择: ${G}${auto_now:-未知}${N}"
    fi
}

# ============================================================
# C5: 节点管理 (list/add/del)
# 配置格式: proxies段为flow-style(每节点一行), proxy-groups段为block-style
# 安全措施: 备份→编辑→API热重载→校验→失败回滚
# ============================================================

# 通过API热重载配置 (clash-rs 失败时保留旧配置继续运行)
_reload_config() {
    # 注意: 禁用 PUT /configs 热重载（会导致 1053 Address in use 断网）
    # 改配置后用 init.d restart 完整重启
    /etc/init.d/clash-rs restart >/dev/null 2>&1
    return $?
}

# 从节点定义文本中提取name (支持 flow/block style)
_node_extract_name() {
    # $1 = 节点定义文本 (可能多行), 取第一个 name: 字段
    printf '%s\n' "$1" | grep -oE 'name:[[:space:]]*"?[^",}[:space:]]+"?' | head -1 | sed 's/name:[[:space:]]*//; s/"//g'
}

# 列出所有节点 (PROXY + AUTO 组)
_node_list() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    nodes=$(get_proxy_nodes)
    if [ -z "$nodes" ]; then
        pl "${R}  未获取到节点列表${N}"
        return 1
    fi
    current=$(get_proxy_now)
    pl "${C}  PROXY 组节点${N} (当前: ${G}${current:-未知}${N})"
    line
    i=0
    echo "$nodes" | while read n; do
        [ -z "$n" ] && continue
        i=$((i+1))
        if [ "$n" = "$current" ]; then
            pl "  ${G}*$i${N}. $n ${G}[当前]${N}"
        else
            pl "  $i. $n"
        fi
    done
    line
    # AUTO 组
    auto_nodes=$(get_group_nodes "AUTO" 2>/dev/null)
    if [ -n "$auto_nodes" ]; then
        auto_now=$(get_group_now "AUTO")
        pl "${C}  AUTO 组${N} (select/cc autoswitch: ${G}${auto_now:-未知}${N})"
        line
        echo "$auto_nodes" | while read n; do
            [ -z "$n" ] && continue
            if [ "$n" = "$auto_now" ]; then
                pl "  ${G}*$n${N} ${G}[当前]${N}"
            else
                pl "  $n"
            fi
        done
        line
    fi
    pl "${Y}  提示: cc node add 添加节点, cc node del 删除节点${N}"
}

# 添加节点 (从粘贴的YAML定义)
_node_add() {
    if [ ! -f "$CONFIG" ]; then
        pl "${R}  配置文件不存在: $CONFIG${N}"
        return 1
    fi
    pl "${C}  添加节点${N}"
    pl "  ${Y}请粘贴节点定义 (flow风格推荐), 输入空行结束:${N}"
    pl "  示例: - {name: \"NEW\", server: 1.2.3.4, port: 443, type: ss, cipher: aes-256-gcm, password: \"pass\"}"
    line
    printf "  > "
    entry=""
    while IFS= read -r line; do
        [ -z "$line" ] && break
        if [ -z "$entry" ]; then
            entry="$line"
        else
            entry="$entry
$line"
        fi
    done
    [ -z "$entry" ] && pl "${R}  未输入内容${N}" && return 1
    # 提取name
    name=$(_node_extract_name "$entry")
    [ -z "$name" ] && pl "${R}  无法从输入中提取 name 字段${N}" && return 1
    pl "  解析到节点名: ${G}${name}${N}"
    # 检查是否已存在
    if grep -qF "name: \"${name}\"" "$CONFIG" 2>/dev/null || grep -qF "name: ${name}," "$CONFIG" 2>/dev/null; then
        pl "${R}  节点 ${name} 已存在于配置中${N}"
        return 1
    fi
    # 规范化: 去掉前导空白, 补2空格缩进
    entry=$(printf '%s\n' "$entry" | sed 's/^[[:space:]]*//')
    case "$entry" in
        "- "*) entry="  $entry" ;;
    esac
    # 确认
    pl "${Y}  即将添加节点 ${name} 到配置并热重载, 确认? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 备份
    local bak="$CONFIG.cc.bak.$(date +%s)"
    cp "$CONFIG" "$bak" 2>/dev/null
    pl "  已备份: $bak"
    # 1. 插入节点定义到 proxies 段末尾 (proxy-groups: 行之前)
    # 2. 在每个 "    proxies:" 行后添加 "      - name" (加入所有组)
    local tmp="${CONFIG}.tmp.$$"
    awk -v entry="$entry" -v node="$name" '
        /^proxy-groups:/ { if(!done) { print entry; done=1 } }
        /^    proxies:/ { print; printf "      - %s\n", node; next }
        { print }
    ' "$CONFIG" > "$tmp" 2>/dev/null
    if [ ! -s "$tmp" ]; then
        pl "${R}  编辑配置失败${N}"
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$CONFIG"
    # 热重载
    pl "  热重载配置..."
    if _reload_config; then
        sleep 1
        if is_running; then
            # 验证节点已加入
            if get_proxy_nodes | grep -qx "$name"; then
                pl "${G}  节点 ${name} 添加成功并已重载${N}"
            else
                pl "${Y}  配置已重载, 但未在节点列表中发现 ${name} (可能配置格式有误)${N}"
            fi
        else
            pl "${R}  重载后服务异常, 回滚配置...${N}"
            cp "$bak" "$CONFIG"
            _reload_config
            sleep 1
            pl "${R}  已回滚, 请检查输入格式${N}"
            return 1
        fi
    else
        pl "${R}  配置重载失败 (格式错误), 回滚...${N}"
        cp "$bak" "$CONFIG"
        _reload_config
        pl "${Y}  已回滚到备份, 服务未受影响${N}"
        return 1
    fi
}

# 删除节点 (从配置移除 + 热重载)
# $1 = 节点名或编号 (为空则交互选择)
_node_del() {
    local target="$1"
    if ! is_running; then
        pl "${R}  clash-rs 未运行, 无法获取节点列表${N}"
        return 1
    fi
    # 获取实际节点 (排除 AUTO/DIRECT 组引用)
    nodes=$(get_proxy_nodes | grep -vE '^(AUTO|DIRECT)$')
    [ -z "$nodes" ] && pl "${R}  无可删除节点${N}" && return 1
    # 交互选择
    if [ -z "$target" ]; then
        pl "${C}  可删除节点${N}"
        line
        i=0
        echo "$nodes" | while read n; do
            [ -z "$n" ] && continue
            i=$((i+1))
            pl "  $i. $n"
        done
        line
        printf "  输入编号或节点名 (0=取消): "
        read choice
        [ -z "$choice" ] || [ "$choice" = "0" ] && return 0
        case "$choice" in
            ''|*[!0-9]*) target="$choice" ;;
            *) target=$(echo "$nodes" | sed -n "${choice}p") ;;
        esac
    fi
    [ -z "$target" ] && pl "${R}  无效选择${N}" && return 1
    # 校验节点存在
    if ! echo "$nodes" | grep -qx "$target"; then
        pl "${R}  节点 ${target} 不在列表中${N}"
        return 1
    fi
    # 确认
    pl "${Y}  即将删除节点: ${target}${N}"
    pl "  ${Y}这会修改配置并热重载, 确认? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 备份
    local bak="$CONFIG.cc.bak.$(date +%s)"
    cp "$CONFIG" "$bak" 2>/dev/null
    pl "  已备份: $bak"
    # 删除: proxies段的定义行 + proxy-groups中的引用行 (精确匹配节点名)
    local tmp="${CONFIG}.tmp.$$"
    awk -v node="$target" '
        # flow-style 代理定义行: "  - {name: \"NODE\"" 或 "  - {name: NODE,"
        /^  - \{/ {
            if (index($0, "name: \"" node "\"") || index($0, "name: " node ",") || index($0, "name: " node "}")) next
            print; next
        }
        # block-style 代理定义: 跳过 "  - name: NODE" 开头的块
        /^  - name:/ {
            s = $0
            sub(/^  - name:[ ]*/, "", s)
            sub(/[[:space:]]*$/, "", s)
            gsub(/^"|"$/, "", s)
            if (s == node) { skip=1; next }
            skip=0
        }
        skip && /^  - name:/ { skip=0 }
        skip && /^[a-zA-Z]/ { skip=0 }
        skip { next }
        # proxy-groups 列表项: "      - NODE" (精确匹配)
        /^[[:space:]]+- / {
            s = $0
            sub(/^[[:space:]]+- /, "", s)
            sub(/[[:space:]]*$/, "", s)
            gsub(/^"|"$/, "", s)
            if (s == node) next
            print; next
        }
        { print }
    ' "$CONFIG" > "$tmp" 2>/dev/null
    if [ ! -s "$tmp" ]; then
        pl "${R}  编辑配置失败${N}"
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$CONFIG"
    # 热重载
    pl "  热重载配置..."
    if _reload_config; then
        sleep 1
        if is_running; then
            if get_proxy_nodes | grep -qx "$target"; then
                pl "${Y}  节点 ${target} 仍存在, 可能重载未生效${N}"
            else
                pl "${G}  节点 ${target} 已删除并重载${N}"
            fi
        else
            pl "${R}  重载后服务异常, 回滚配置...${N}"
            cp "$bak" "$CONFIG"
            _reload_config
            sleep 1
            pl "${R}  已回滚${N}"
            return 1
        fi
    else
        pl "${R}  配置重载失败, 回滚...${N}"
        cp "$bak" "$CONFIG"
        _reload_config
        pl "${Y}  已回滚到备份, 服务未受影响${N}"
        return 1
    fi
}

do_node() {
    local sub="${1:-}"
    case "$sub" in
        list|ls|"") _node_list ;;
        add) _node_add ;;
        del|delete|rm) _node_del "${2:-}" ;;
        *) pl "${R}  用法: cc node [list|add|del]${N}"; return 1 ;;
    esac
}

# 节点管理交互子菜单 (菜单入口15)
do_node_menu() {
    while true; do
        printf "\n"
        line
        pl "${C}  节点管理${N}"
        line
        pl "  ${W}1${N}. 列出所有节点"
        pl "  ${W}2${N}. 添加节点 (粘贴YAML)"
        pl "  ${W}3${N}. 删除节点"
        pl "  ${W}0${N}. 返回上级菜单"
        printf "\n  请选择: "
        read choice
        case $choice in
            1) _node_list; pause_for_input ;;
            2) _node_add; pause_for_input ;;
            3) _node_del; pause_for_input ;;
            0) return ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# ============================================================
# C1: 配置备份与回滚 (cc backup [list|restore])
#   - 备份目录: $BACKUP_DIR (= $CLASH_DIR/backup/)
#   - 命名: config.YYYYMMDD-HHMMSS.yaml
#   - 默认保留最近 20 份, 超出自动清理最旧
# ============================================================
BACKUP_KEEP=20

do_backup() {
    local sub="${1:-}"
    mkdir -p "$BACKUP_DIR" 2>/dev/null
    case "$sub" in
        list|ls) _backup_list ;;
        restore|rollback) _backup_restore "${2:-}" ;;
        ""|create|save) _backup_create ;;
        *) pl "${R}  用法: cc backup [list|restore [编号/文件名]]${N}"; return 1 ;;
    esac
}

_backup_create() {
    if [ ! -f "$CONFIG" ]; then
        pl "${R}  配置文件不存在: $CONFIG${N}"
        return 1
    fi
    local ts=$(date +%Y%m%d-%H%M%S)
    local bak="$BACKUP_DIR/config.$ts.yaml"
    if cp "$CONFIG" "$bak" 2>/dev/null; then
        local sz=$(wc -c < "$bak" 2>/dev/null)
        pl "${G}  配置已备份${N}"
        pl "  文件: $bak (${sz}B)"
        # 附加元信息 (节点数 / 时间)
        local cnt=$(grep -c '^  - {name:' "$CONFIG" 2>/dev/null || echo 0)
        pl "  节点数: $cnt  时间: $ts"
        # 自动清理: 保留最近 BACKUP_KEEP 份
        _backup_prune
    else
        pl "${R}  备份失败${N}"
        return 1
    fi
}

_backup_list() {
    if [ ! -d "$BACKUP_DIR" ]; then
        pl "${Y}  备份目录尚未创建${N}"
        return 0
    fi
    local files=$(ls -1 "$BACKUP_DIR"/config.*.yaml 2>/dev/null | sort)
    if [ -z "$files" ]; then
        pl "${Y}  暂无配置备份${N}"
        return 0
    fi
    pl "${C}  配置备份列表 (按时间升序)${N}"
    line
    printf "  %-4s %-20s %-10s %s\n" "编号" "时间戳" "大小" "节点数"
    line
    local i=0
    echo "$files" | while read f; do
        [ -z "$f" ] && continue
        i=$((i+1))
        local bn=$(basename "$f")
        # 提取时间戳 config.YYYYMMDD-HHMMSS.yaml
        local ts=$(echo "$bn" | sed -n 's/^config\.\([0-9]\{8\}-[0-9]\{6\}\)\.yaml$/\1/p')
        local sz=$(wc -c < "$f" 2>/dev/null)
        local cnt=$(grep -c '^  - {name:' "$f" 2>/dev/null || echo 0)
        # 格式化时间戳 20260801-120530 -> 2026-08-01 12:05:30
        local pretty="-"
        if [ -n "$ts" ]; then
            pretty=$(echo "$ts" | sed 's/\(....\)\(..\)\(..\)-\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
        fi
        printf "  %-4s %-20s %-10s %s\n" "$i" "$pretty" "${sz}B" "$cnt"
    done
    line
    pl "  回滚: ${G}cc backup restore <编号>${N}  或  ${G}cc backup restore <文件名>${N}"
}

_backup_restore() {
    local target="$1"
    if [ ! -d "$BACKUP_DIR" ]; then
        pl "${R}  备份目录不存在${N}"
        return 1
    fi
    local files=$(ls -1 "$BACKUP_DIR"/config.*.yaml 2>/dev/null | sort)
    if [ -z "$files" ]; then
        pl "${R}  无可用备份${N}"
        return 1
    fi
    local picked=""
    if [ -z "$target" ]; then
        # 交互选择 (倒序, 最新在前)
        pl "${C}  可用备份 (最新在前)${N}"
        line
        local arr=""
        local i=0
        echo "$files" | awk '{a[NR]=$0}END{for(i=NR;i>=1;i--)print a[i]}' | while read f; do
            [ -z "$f" ] && continue
            i=$((i+1))
            local bn=$(basename "$f")
            local ts=$(echo "$bn" | sed -n 's/^config\.\([0-9]\{8\}-[0-9]\{6\}\)\.yaml$/\1/p')
            local pretty="$ts"
            [ -n "$ts" ] && pretty=$(echo "$ts" | sed 's/\(....\)\(..\)\(..\)-\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
            local sz=$(wc -c < "$f" 2>/dev/null)
            local cnt=$(grep -c '^  - {name:' "$f" 2>/dev/null || echo 0)
            pl "  ${W}$i${N}. $pretty  (${sz}B, ${cnt}节点)  $bn"
        done
        line
        printf "  输入编号 (0=取消): "
        read choice
        [ -z "$choice" ] || [ "$choice" = "0" ] && { pl "  已取消"; return 0; }
        case "$choice" in
            ''|*[!0-9]*) pl "${R}  无效编号${N}"; return 1 ;;
        esac
        picked=$(echo "$files" | awk '{a[NR]=$0}END{for(i=NR;i>=1;i--)print a[i]}' | sed -n "${choice}p")
        [ -z "$picked" ] && { pl "${R}  编号超出范围${N}"; return 1; }
    else
        # 编号或文件名
        case "$target" in
            ''|*[!0-9]*)
                # 文件名: 允许完整路径或 basename, 自动补全前缀
                if [ -f "$target" ]; then
                    picked="$target"
                elif [ -f "$BACKUP_DIR/$target" ]; then
                    picked="$BACKUP_DIR/$target"
                else
                    pl "${R}  找不到备份: $target${N}"
                    return 1
                fi
                ;;
            *)
                # 数字编号 (按升序, 与 list 一致)
                picked=$(echo "$files" | sed -n "${target}p")
                [ -z "$picked" ] && { pl "${R}  编号超出范围${N}"; return 1; }
                ;;
        esac
    fi
    [ -z "$picked" ] || [ ! -f "$picked" ] && { pl "${R}  无效备份${N}"; return 1; }
    # 确认
    local bn=$(basename "$picked")
    local cnt=$(grep -c '^  - {name:' "$picked" 2>/dev/null || echo 0)
    pl "${Y}  即将从备份恢复: $bn ($cnt 节点)${N}"
    pl "  ${Y}当前配置会被覆盖 (会先自动备份当前配置), 确认? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 先备份当前配置 (前缀 prev.)
    local ts=$(date +%Y%m%d-%H%M%S)
    local prevbak="$BACKUP_DIR/prev.config.$ts.yaml"
    cp "$CONFIG" "$prevbak" 2>/dev/null
    pl "  当前配置已存为: $prevbak"
    # 恢复
    if cp "$picked" "$CONFIG" 2>/dev/null; then
        pl "${G}  配置已恢复: $bn${N}"
        # 热重载
        if is_running; then
            pl "  热重载配置..."
            if _reload_config; then
                sleep 1
                if is_running; then
                    pl "${G}  重载成功${N}"
                else
                    pl "${R}  重载后服务异常, 自动回滚到 prev 备份${N}"
                    cp "$prevbak" "$CONFIG"
                    _reload_config
                    return 1
                fi
            else
                pl "${R}  重载失败, 自动回滚${N}"
                cp "$prevbak" "$CONFIG"
                _reload_config
                return 1
            fi
        else
            pl "${Y}  服务未运行, 下次启动时生效${N}"
        fi
    else
        pl "${R}  恢复失败${N}"
        return 1
    fi
}

_backup_prune() {
    [ -d "$BACKUP_DIR" ] || return 0
    # 仅清理 config.*.yaml (不清理 prev.config.*)
    local n=$(ls -1 "$BACKUP_DIR"/config.*.yaml 2>/dev/null | wc -l)
    [ "$n" -le "$BACKUP_KEEP" ] && return 0
    # 删除最旧的 (ls已按名称升序, 即时间升序)
    local del=$((n - BACKUP_KEEP))
    ls -1 "$BACKUP_DIR"/config.*.yaml 2>/dev/null | sort | head -n "$del" | while read f; do
        rm -f "$f"
    done
}

# ============================================================
# C3: 二进制版本管理 (cc binver / cc binbak [backup|restore])
#   - 备份目录: $BINBAK_DIR (= /tmp/clash-rs-binbak, tmpfs)
#   - 命名: clash-rs.bin.YYYYMMDD-HHMMSS + .ver sidecar (存版本字符串)
#   - 保留最近 3 份 (3×16MB=48MB, /tmp有82MB)
#   - 注意: /tmp是tmpfs, 重启后备份丢失 (用于升级前备份+即时回滚)
# ============================================================
BINBAK_KEEP=3

do_binver() {
    if [ ! -x "$CLASH_BIN" ]; then
        pl "${R}  二进制不存在或不可执行: $CLASH_BIN${N}"
        return 1
    fi
    pl "${C}  clash-rs 二进制信息${N}"
    line
    local binver=$($CLASH_BIN -v 2>/dev/null | head -1)
    [ -z "$binver" ] && binver=$($CLASH_BIN --version 2>/dev/null | head -1)
    pl "  版本:   ${G}${binver:-未知}${N}"
    local binsz=$(wc -c < "$CLASH_BIN" 2>/dev/null)
    pl "  路径:   $CLASH_BIN"
    pl "  大小:   $((binsz/1024)) KB ($binsz B)"
    # 文件修改时间
    local mtime=$(ls -l "$CLASH_BIN" 2>/dev/null | awk '{print $6,$7,$8}')
    pl "  修改:   $mtime"
    # 架构
    local arch=$(uname -m 2>/dev/null)
    local kernel=$(uname -r 2>/dev/null)
    pl "  系统:   $arch / $kernel"
    # 已备份的二进制 (从 .ver sidecar 读版本, 不执行备份的二进制)
    if [ -d "$BINBAK_DIR" ] && ls "$BINBAK_DIR"/clash-rs.bin.* >/dev/null 2>&1; then
        pl "  ${C}已备份的二进制 (${Y}/tmp, 重启丢失${N}${C}):${N}"
        ls -1 "$BINBAK_DIR"/clash-rs.bin.* 2>/dev/null | grep -v '\.ver$' | sort | while read f; do
            [ -z "$f" ] && continue
            local bn=$(basename "$f")
            local bsz=$(wc -c < "$f" 2>/dev/null)
            # 从 .ver sidecar 读版本
            local bver="(无版本信息)"
            if [ -f "${f}.ver" ]; then
                bver=$(cat "${f}.ver" 2>/dev/null | head -1)
                [ -z "$bver" ] && bver="(空版本)"
            fi
            pl "    - $bn  ${bver}  ($((bsz/1024))KB)"
        done
    else
        pl "  ${Y}暂无二进制备份 (建议: cc binbak backup)${N}"
    fi
}

do_binbak() {
    local sub="${1:-}"
    mkdir -p "$BINBAK_DIR" 2>/dev/null
    case "$sub" in
        backup|save|"") _binbak_create ;;
        restore|rollback) _binbak_restore "${2:-}" ;;
        list|ls) _binbak_list ;;
        *) pl "${R}  用法: cc binbak [backup|restore [编号]|list]${N}"; return 1 ;;
    esac
}

_binbak_create() {
    if [ ! -x "$CLASH_BIN" ]; then
        pl "${R}  二进制不存在: $CLASH_BIN${N}"
        return 1
    fi
    # 磁盘空间检查 (/tmp是tmpfs, df输出1K-blocks, binsz是字节)
    local binsz=$(wc -c < "$CLASH_BIN" 2>/dev/null)
    local tmp_free_kb=$(df /tmp 2>/dev/null | awk 'NR==2{print $4}')
    [ -z "$tmp_free_kb" ] && tmp_free_kb=0
    # binsz转KB, 与df的1K-blocks比较
    local binsz_kb=$(( (binsz + 1023) / 1024 ))
    if [ "$tmp_free_kb" -gt 0 ] 2>/dev/null && [ "$tmp_free_kb" -lt "$binsz_kb" ] 2>/dev/null; then
        pl "${R}  /tmp 空间不足: 需要${binsz_kb}KB, 可用${tmp_free_kb}KB${N}"
        return 1
    fi
    local ts=$(date +%Y%m%d-%H%M%S)
    local bak="$BINBAK_DIR/clash-rs.bin.$ts"
    local ver_file="${bak}.ver"
    # 获取当前版本 (备份前获取, 避免执行备份文件)
    local cur_ver=$($CLASH_BIN -v 2>/dev/null | head -1)
    [ -z "$cur_ver" ] && cur_ver="(无法获取版本)"
    if cp "$CLASH_BIN" "$bak" 2>/dev/null; then
        chmod +x "$bak" 2>/dev/null
        # 验证备份完整性 (大小一致)
        local bak_sz=$(wc -c < "$bak" 2>/dev/null)
        if [ "$bak_sz" != "$binsz" ] 2>/dev/null; then
            pl "${R}  备份不完整: 原始${binsz}B, 备份${bak_sz}B${N}"
            rm -f "$bak" "$ver_file" 2>/dev/null
            return 1
        fi
        # 写版本 sidecar
        echo "$cur_ver" > "$ver_file" 2>/dev/null
        pl "${G}  二进制备份成功${N}"
        pl "  文件:   $bak"
        pl "  大小:   $((bak_sz/1024)) KB"
        pl "  版本:   $cur_ver"
        pl "  ${Y}位置: /tmp (tmpfs, 重启后丢失)${N}"
        # 清理: 仅保留最近 BINBAK_KEEP 份 (连同 .ver sidecar)
        _binbak_prune
    else
        pl "${R}  备份失败 (空间不足或权限问题)${N}"
        rm -f "$bak" "$ver_file" 2>/dev/null
        return 1
    fi
}

_binbak_prune() {
    [ -d "$BINBAK_DIR" ] || return 0
    # 仅清理 clash-rs.bin.* (不清理 prev.*), 排除 .ver 文件
    local files=$(ls -1 "$BINBAK_DIR"/clash-rs.bin.* 2>/dev/null | grep -v '\.ver$' | sort)
    [ -z "$files" ] && return 0
    local n=$(echo "$files" | wc -l)
    [ "$n" -le "$BINBAK_KEEP" ] && return 0
    local del=$((n - BINBAK_KEEP))
    echo "$files" | head -n "$del" | while read f; do
        rm -f "$f" "${f}.ver" 2>/dev/null
    done
}

_binbak_list() {
    if [ ! -d "$BINBAK_DIR" ]; then
        pl "${Y}  备份目录尚未创建${N}"
        return 0
    fi
    local files=$(ls -1 "$BINBAK_DIR"/clash-rs.bin.* 2>/dev/null | grep -v '\.ver$' | sort)
    if [ -z "$files" ]; then
        pl "${Y}  暂无二进制备份${N}"
        pl "  ${Y}(备份位置: /tmp, 重启后丢失)${N}"
        return 0
    fi
    pl "${C}  二进制备份列表 (按时间升序)${N}"
    pl "  ${Y}位置: $BINBAK_DIR (tmpfs, 重启后丢失)${N}"
    line
    local i=0
    echo "$files" | while read f; do
        [ -z "$f" ] && continue
        i=$((i+1))
        local bn=$(basename "$f")
        local bsz=$(wc -c < "$f" 2>/dev/null)
        # 从 .ver sidecar 读版本
        local bver="(无版本信息)"
        if [ -f "${f}.ver" ]; then
            bver=$(cat "${f}.ver" 2>/dev/null | head -1)
            [ -z "$bver" ] && bver="(空版本)"
        fi
        printf "  %-4s %-22s %s\n" "$i" "$((bsz/1024))KB" "$bver"
        pl "       ${Y}$bn${N}"
    done
    line
    pl "  回滚: ${G}cc binbak restore <编号>${N}"
}

_binbak_restore() {
    local target="$1"
    local files=$(ls -1 "$BINBAK_DIR"/clash-rs.bin.* 2>/dev/null | grep -v '\.ver$' | sort)
    if [ -z "$files" ]; then
        pl "${R}  无可用二进制备份${N}"
        return 1
    fi
    local picked=""
    if [ -z "$target" ]; then
        # 交互选择 (倒序, 最新在前)
        pl "${C}  可用备份 (最新在前)${N}"
        line
        local i=0
        echo "$files" | awk '{a[NR]=$0}END{for(i=NR;i>=1;i--)print a[i]}' | while read f; do
            [ -z "$f" ] && continue
            i=$((i+1))
            local bn=$(basename "$f")
            local bsz=$(wc -c < "$f" 2>/dev/null)
            local bver="(无版本信息)"
            if [ -f "${f}.ver" ]; then
                bver=$(cat "${f}.ver" 2>/dev/null | head -1)
                [ -z "$bver" ] && bver="(空版本)"
            fi
            pl "  ${W}$i${N}. $bn  ${bver}  ($((bsz/1024))KB)"
        done
        line
        printf "  输入编号 (0=取消): "
        read choice
        [ -z "$choice" ] || [ "$choice" = "0" ] && { pl "  已取消"; return 0; }
        case "$choice" in
            ''|*[!0-9]*) pl "${R}  无效编号${N}"; return 1 ;;
        esac
        picked=$(echo "$files" | awk '{a[NR]=$0}END{for(i=NR;i>=1;i--)print a[i]}' | sed -n "${choice}p")
        [ -z "$picked" ] && { pl "${R}  编号超出范围${N}"; return 1; }
    else
        case "$target" in
            ''|*[!0-9]*)
                if [ -f "$target" ]; then
                    picked="$target"
                elif [ -f "$BINBAK_DIR/$target" ]; then
                    picked="$BINBAK_DIR/$target"
                else
                    pl "${R}  找不到备份: $target${N}"
                    return 1
                fi
                ;;
            *)
                picked=$(echo "$files" | sed -n "${target}p")
                [ -z "$picked" ] && { pl "${R}  编号超出范围${N}"; return 1; }
                ;;
        esac
    fi
    [ -z "$picked" ] || [ ! -f "$picked" ] && { pl "${R}  无效备份${N}"; return 1; }
    # 确认
    local bn=$(basename "$picked")
    local bver="(无版本信息)"
    if [ -f "${picked}.ver" ]; then
        bver=$(cat "${picked}.ver" 2>/dev/null | head -1)
        [ -z "$bver" ] && bver="(空版本)"
    fi
    pl "${Y}  即将恢复二进制: $bn${N}"
    pl "  ${Y}版本: $bver${N}"
    pl "  ${Y}当前运行中的 clash-rs 会被停止, 当前二进制会被覆盖, 确认? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  已取消"; return 0 ;;
    esac
    # 先备份当前二进制 (前缀 prev.)
    local ts=$(date +%Y%m%d-%H%M%S)
    local prevbak="$BINBAK_DIR/prev.clash-rs.bin.$ts"
    cp "$CLASH_BIN" "$prevbak" 2>/dev/null
    chmod +x "$prevbak" 2>/dev/null
    # 也备份版本 sidecar
    local cur_ver=$($CLASH_BIN -v 2>/dev/null | head -1)
    [ -z "$cur_ver" ] && cur_ver="(无法获取版本)"
    echo "$cur_ver" > "${prevbak}.ver" 2>/dev/null
    pl "  当前二进制已存为: $prevbak"
    # 停止服务
    pl "  停止服务..."
    do_stop >/dev/null 2>&1
    sleep 1
    # 恢复
    if cp "$picked" "$CLASH_BIN" 2>/dev/null; then
        chmod +x "$CLASH_BIN" 2>/dev/null
        pl "${G}  二进制已恢复: $bn${N}"
        pl "  新版本: $($CLASH_BIN -v 2>/dev/null | head -1)"
        # 重启服务
        pl "  启动服务..."
        if do_start; then
            sleep 2
            if is_running; then
                pl "${G}  服务已启动, 二进制回滚完成${N}"
            else
                pl "${R}  服务启动失败, 请检查二进制兼容性${N}"
                pl "  ${Y}可手动回滚: cc binbak restore $prevbak${N}"
                return 1
            fi
        else
            pl "${R}  启动失败${N}"
            return 1
        fi
    else
        pl "${R}  恢复失败${N}"
        return 1
    fi
}

do_monitor() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi
    pl "${C}  实时监控 (Ctrl+C退出)${N}"
    sleep 1

    # 初始化前值用于计算CPU使用率和NSS包速率
    prev_cpu_line=$(head -1 /proc/stat 2>/dev/null)
    prev_time=$(date +%s)
    prev_nss_rx=$(cat /sys/kernel/debug/qca-nss-drv/stats/n2h 2>/dev/null | grep "n2h_rx_pkts" | awk '{print $3}')
    prev_nss_tx=$(cat /sys/kernel/debug/qca-nss-drv/stats/n2h 2>/dev/null | grep "n2h_tx_pkts" | awk '{print $3}')
    # C7: 初始化clash流量前值 (从API获取累计上下行字节)
    _conn_data=$(api "/connections" 2>/dev/null)
    prev_up_total=$(echo "$_conn_data" | grep -o '"uploadTotal":[0-9]*' | head -1 | cut -d: -f2)
    prev_down_total=$(echo "$_conn_data" | grep -o '"downloadTotal":[0-9]*' | head -1 | cut -d: -f2)
    prev_conn_cnt=$(echo "$_conn_data" | grep -o '"id":"' | wc -l)
    sleep 1  # 确保第一次采样有足够间隔

    while true; do
        PID=$(get_pid)
        [ -z "$PID" ] && pl "${R}  clash-rs 已停止${N}" && break

        # CPU频率
        CPU0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        CPU1=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq 2>/dev/null)
        CPU0_MHZ="N/A"; CPU1_MHZ="N/A"
        [ -n "$CPU0" ] && CPU0_MHZ="$((CPU0/1000))MHz"
        [ -n "$CPU1" ] && CPU1_MHZ="$((CPU1/1000))MHz"

        # ===== 三个温度 (SoC/WiFi2.4/WiFi5) =====
        T0=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
        T1=$(cat /sys/class/thermal/thermal_zone1/temp 2>/dev/null)
        T2=$(cat /sys/class/thermal/thermal_zone2/temp 2>/dev/null)
        [ "$T0" -gt 1000 ] 2>/dev/null && T0=$((T0/1000))
        [ "$T1" -gt 1000 ] 2>/dev/null && T1=$((T1/1000))
        [ "$T2" -gt 1000 ] 2>/dev/null && T2=$((T2/1000))
        T0="${T0:-?}"; T1="${T1:-?}"; T2="${T2:-?}"
        # 温度颜色 (>85红 >75黄 否则绿)
        if [ "$T0" -gt 85 ] 2>/dev/null; then TC0=$R
        elif [ "$T0" -gt 75 ] 2>/dev/null; then TC0=$Y
        else TC0=$G; fi
        if [ "$T1" -gt 85 ] 2>/dev/null; then TC1=$R
        elif [ "$T1" -gt 75 ] 2>/dev/null; then TC1=$Y
        else TC1=$G; fi
        if [ "$T2" -gt 85 ] 2>/dev/null; then TC2=$R
        elif [ "$T2" -gt 75 ] 2>/dev/null; then TC2=$Y
        else TC2=$G; fi

        # ===== NSS CPU百分比 (硬件加速引擎负载) =====
        NSS_CPU=$(cat /sys/kernel/debug/qca-nss-drv/stats/cpu_load_ubi 2>/dev/null | grep -oE '[0-9]+%' | sed -n '2p' | tr -d '%')
        [ -z "$NSS_CPU" ] && NSS_CPU="?"

        # ===== CPU使用率 (从/proc/stat计算) =====
        cur_cpu_line=$(head -1 /proc/stat 2>/dev/null)
        cur_time=$(date +%s)
        dt=$((cur_time - prev_time))
        [ "$dt" -le 0 ] && dt=1
        set -- $cur_cpu_line
        cur_total=$(( $2 + $3 + $4 + $5 + $6 + $7 + $8 ))
        cur_idle=$5
        set -- $prev_cpu_line
        prev_total=$(( $2 + $3 + $4 + $5 + $6 + $7 + $8 ))
        prev_idle=$5
        total_diff=$((cur_total - prev_total))
        idle_diff=$((cur_idle - prev_idle))
        [ "$total_diff" -gt 0 ] 2>/dev/null && cpu_usage=$(( 100 - (idle_diff * 100 / total_diff) )) || cpu_usage=0

        # ===== NSS包速率 (pps) =====
        cur_nss_rx=$(cat /sys/kernel/debug/qca-nss-drv/stats/n2h 2>/dev/null | grep "n2h_rx_pkts" | awk '{print $3}')
        cur_nss_tx=$(cat /sys/kernel/debug/qca-nss-drv/stats/n2h 2>/dev/null | grep "n2h_tx_pkts" | awk '{print $3}')
        nss_rx_rate=0; nss_tx_rate=0
        [ -n "$cur_nss_rx" ] && [ -n "$prev_nss_rx" ] && nss_rx_rate=$(( (cur_nss_rx - prev_nss_rx) / dt ))
        [ -n "$cur_nss_tx" ] && [ -n "$prev_nss_tx" ] && nss_tx_rate=$(( (cur_nss_tx - prev_nss_tx) / dt ))
        if [ "$nss_rx_rate" -ge 1000000 ] 2>/dev/null; then NSS_RX_S="$((nss_rx_rate/1000000))M"
        elif [ "$nss_rx_rate" -ge 1000 ] 2>/dev/null; then NSS_RX_S="$((nss_rx_rate/1000))K"
        else NSS_RX_S="$nss_rx_rate"; fi
        if [ "$nss_tx_rate" -ge 1000000 ] 2>/dev/null; then NSS_TX_S="$((nss_tx_rate/1000000))M"
        elif [ "$nss_tx_rate" -ge 1000 ] 2>/dev/null; then NSS_TX_S="$((nss_tx_rate/1000))K"
        else NSS_TX_S="$nss_tx_rate"; fi

        # ===== C7: clash-rs 实时流量速率 (从API /connections累计值差分) =====
        _conn_data=$(api "/connections" 2>/dev/null)
        cur_up_total=$(echo "$_conn_data" | grep -o '"uploadTotal":[0-9]*' | head -1 | cut -d: -f2)
        cur_down_total=$(echo "$_conn_data" | grep -o '"downloadTotal":[0-9]*' | head -1 | cut -d: -f2)
        cur_conn_cnt=$(echo "$_conn_data" | grep -o '"id":"' | wc -l)
        up_rate=0; down_rate=0
        [ -n "$cur_up_total" ] && [ -n "$prev_up_total" ] && up_rate=$(( (cur_up_total - prev_up_total) / dt ))
        [ -n "$cur_down_total" ] && [ -n "$prev_down_total" ] && down_rate=$(( (cur_down_total - prev_down_total) / dt ))
        # 防止计数器重置导致负值
        [ "$up_rate" -lt 0 ] 2>/dev/null && up_rate=0
        [ "$down_rate" -lt 0 ] 2>/dev/null && down_rate=0

        # 内存
        RSS=$(get_rss)
        MEM_TOTAL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $2/1024}')
        MEM_USED=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/1024}')
        MEM_AVAIL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $7/1024}')
        MEM_PCT=0
        [ "$MEM_TOTAL" -gt 0 ] 2>/dev/null && MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))

        # ECM & conntrack
        ECM=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count 2>/dev/null)
        CONN=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)
        CONN_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)
        CONN_PCT=0
        [ "$CONN_MAX" -gt 0 ] 2>/dev/null && CONN_PCT=$((CONN * 100 / CONN_MAX))

        # 内存保护
        MEM_LIMIT=$(get_mem_threshold_mb)
        HARD_LIMIT=$((MEM_LIMIT * 3 / 2))

        # 颜色判断
        if [ "$MEM_PCT" -lt 65 ] 2>/dev/null; then MEM_C=$G
        elif [ "$MEM_PCT" -lt 85 ] 2>/dev/null; then MEM_C=$Y
        else MEM_C=$R; fi

        RSS_INT=$(echo "$RSS" | awk '{print int($1)}')
        if [ "$RSS_INT" -lt 30 ] 2>/dev/null; then RSS_C=$G
        elif [ "$RSS_INT" -lt 50 ] 2>/dev/null; then RSS_C=$Y
        else RSS_C=$R; fi

        if [ "$RSS_INT" -gt "$HARD_LIMIT" ] 2>/dev/null && [ "$HARD_LIMIT" -gt 0 ] 2>/dev/null; then
            MEM_STATUS="${R}HARD${N}(关旧连接)"
        elif [ "$RSS_INT" -gt "$MEM_LIMIT" ] 2>/dev/null && [ "$MEM_LIMIT" -gt 0 ] 2>/dev/null; then
            MEM_STATUS="${Y}SOFT${N}(拒新连接)"
        else
            MEM_STATUS="${G}正常${N}"
        fi

        # CPU使用率颜色
        if [ "$cpu_usage" -lt 50 ] 2>/dev/null; then CPU_C=$G
        elif [ "$cpu_usage" -lt 80 ] 2>/dev/null; then CPU_C=$Y
        else CPU_C=$R; fi

        # NSS CPU颜色
        if [ "$NSS_CPU" -lt 50 ] 2>/dev/null; then NSS_C=$G
        elif [ "$NSS_CPU" -lt 80 ] 2>/dev/null; then NSS_C=$Y
        else NSS_C=$R; fi

        # 连接数颜色
        if [ "$CONN_PCT" -lt 50 ] 2>/dev/null; then CONN_C=$G
        elif [ "$CONN_PCT" -lt 80 ] 2>/dev/null; then CONN_C=$Y
        else CONN_C=$R; fi

        # S5: 滚动模式 (不清屏, 保留历史, 用分隔线区分每次更新)
        pl "${C}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${N}"
        pl "${W}  clash-rs 实时监控  ${Y}$(date '+%H:%M:%S')${N}  ${W}连接${N}:${cur_conn_cnt:-?}"
        pl "  ${W}CPU${N} 使用率:${CPU_C}${cpu_usage}%${N}  频率:${CPU0_MHZ}/${CPU1_MHZ}"
        pl "  ${W}NSS${N} 负载:${NSS_C}${NSS_CPU}%${N}  (硬件加速引擎)"
        pl "  ${W}温度${N} SoC:${TC0}${T0}°C${N}  WiFi2.4:${TC1}${T1}°C${N}  WiFi5:${TC2}${T2}°C${N}"
        pl "${C}───────────────────────────────────────${N}"
        pl "  ${W}内存${N} ${MEM_C}${MEM_USED}MB${N}/${MEM_TOTAL}MB(${MEM_PCT}%) 可用:${MEM_AVAIL}MB"
        pl "  ${W}clash${N} RSS:${RSS_C}${RSS}MB${N} Soft:${MEM_LIMIT}MB Hard:${HARD_LIMIT}MB ${MEM_STATUS}"
        pl "${C}───────────────────────────────────────${N}"
        pl "  ${W}NSS流量${N} RX:${G}${NSS_RX_S}${N}pps TX:${G}${NSS_TX_S}${N}pps"
        pl "  ${W}clash流量${N} ↑:${G}$(_fmt_bytes "$up_rate")${N}/s ↓:${G}$(_fmt_bytes "$down_rate")${N}/s"
        pl "  ${W}连接${N} ECM:${ECM:-0} conntrack:${CONN_C}${CONN:-0}/${CONN_MAX:-0}${N}(${CONN_PCT}%)"
        pl "${C}───────────────────────────────────────${N}"
        pl "  ${W}运行${N} $(get_uptime)  ${W}节点${N} $(get_proxy_now)"
        pl ""

        # 更新前值
        prev_cpu_line="$cur_cpu_line"
        prev_time=$cur_time
        prev_nss_rx="$cur_nss_rx"
        prev_nss_tx="$cur_nss_tx"
        prev_up_total="$cur_up_total"
        prev_down_total="$cur_down_total"
        prev_conn_cnt="$cur_conn_cnt"

        sleep 2
    done
}

do_log() {
    pl "${C}  === clash-rs 日志 (最近30行) ===${N}"
    if [ -f "$LOG_FILE" ]; then
        tail -30 $LOG_FILE
    else
        pl "${Y}  无日志文件${N}"
    fi
    echo ""
    pl "${C}  === 看门狗日志 (最近10行) ===${N}"
    if [ -f "$WATCHDOG_LOG" ]; then
        tail -10 $WATCHDOG_LOG
    else
        pl "${Y}  无看门狗日志${N}"
    fi
    echo ""
    pl "${C}  === dmesg OOM记录 ===${N}"
    oomlog=$(dmesg 2>/dev/null | grep -i "oom\|killed.*clash" | tail -5)
    if [ -n "$oomlog" ]; then
        echo "$oomlog"
    else
        pl "${G}  无OOM记录${N}"
    fi
}

do_flush() {
    pl "${C}  清理系统缓存...${N}"
    # 安全清理: sync两次确保脏页写入, 只清pagecache(1)不清dentries/inodes
    # 注意: echo 3会清dentries/inodes导致后续文件操作变慢(需重建缓存)
    #       echo 1只清pagecache, 更安全, 不会影响文件系统性能
    sync 2>/dev/null
    sleep 1
    sync 2>/dev/null
    # 检查 drop_caches 是否可写 (B4: 失败要提示)
    if [ -w /proc/sys/vm/drop_caches ]; then
        if echo 1 > /proc/sys/vm/drop_caches 2>/dev/null; then
            FLUSH_OK=1
        else
            FLUSH_OK=0
        fi
    else
        FLUSH_OK=0
    fi
    sleep 1
    sync 2>/dev/null
    if [ "$FLUSH_OK" = "1" ]; then
        pl "${G}  pagecache 已清理${N}"
    else
        pl "${Y}  警告: drop_caches 写入失败 (内核可能不支持或权限不足)${N}"
    fi
    if is_running; then
        RSS=$(get_rss)
        pl "  clash-rs RSS: ${RSS}MB"
    fi
    MEM_AVAIL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $7/1024}')
    MEM_TOTAL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $2/1024}')
    pl "${G}  可用内存: ${MEM_AVAIL}MB / 总内存: ${MEM_TOTAL}MB${N}"
}

do_nettest() {
    pl "${C}  网络连通性测试...${N}"
    # 直连测试
    baidu=$(curl -s -o /dev/null -w '%{http_code} %{time_total}s' --connect-timeout 5 http://www.baidu.com 2>/dev/null)
    pl "  百度(直连): $baidu"
    # 代理测试
    google=$(curl -s -o /dev/null -w '%{http_code} %{time_total}s' --connect-timeout 5 -x http://127.0.0.1:7890 https://www.google.com 2>/dev/null)
    pl "  Google(代理): $google"
    youtube=$(curl -s -o /dev/null -w '%{http_code} %{time_total}s' --connect-timeout 5 -x http://127.0.0.1:7890 https://www.youtube.com 2>/dev/null)
    pl "  YouTube(代理): $youtube"
    # DNS测试: 查询本地 dnsmasq(127.0.0.1:53), dnsmasq 将非CN域名转发到 clash-rs(1053)
    # 链路: 客户端 → dnsmasq:53 → clash-rs:1053 → 上游DoH/UDP
    # 注意: busybox nslookup 输出 "Address 1: IP", 用$NF取最后一个字段(IP)
    dns_baidu=$(nslookup www.baidu.com 127.0.0.1 2>/dev/null | grep -A1 "Name:" | grep "Address" | head -1 | awk '{print $NF}')
    dns_google=$(nslookup www.google.com 127.0.0.1 2>/dev/null | grep -A1 "Name:" | grep "Address" | head -1 | awk '{print $NF}')
    pl "  DNS百度(dnsmasq→clash): ${dns_baidu:-失败}"
    pl "  DNS谷歌(dnsmasq→clash): ${dns_google:-失败}"
    # 透明代理测试
    pl ""
    pl "${C}  透明代理规则:${N}"
    ipt_cnt=$(iptables -t nat -L clash_reroute -n 2>/dev/null | grep -c REDIRECT)
    dns_cnt=$(iptables -t nat -L clash_dns -n 2>/dev/null | wc -l)
    cn_cnt=$(ipset list cn_ip -t 2>/dev/null | grep "Number of entries" | awk '{print $4}')
    pl "  TCP重定向规则: ${ipt_cnt}"
    pl "  DNS劫持规则: ${dns_cnt}"
    pl "  CN IP条目: ${cn_cnt:-0}"
}

# ============================================================
# C2: 一键诊断 (cc doctor)
# 检查: 二进制/配置/PID/端口/DNS/iptables/内存/API/看门狗
# ============================================================
do_doctor() {
    pl "${C}  ═══ clash-rs 一键诊断 ═══${N}"
    line
    PASS=0; WARN=0; FAIL=0

    # 1. 二进制检查
    if [ -x "$CLASH_BIN" ]; then
        pl "  ${G}[PASS]${N} 二进制存在且可执行"
        PASS=$((PASS+1))
    elif [ -f "$CLASH_BIN" ]; then
        pl "  ${Y}[WARN]${N} 二进制存在但不可执行 (修复: chmod +x $CLASH_BIN)"
        WARN=$((WARN+1))
    else
        pl "  ${R}[FAIL]${N} 二进制不存在: $CLASH_BIN"
        FAIL=$((FAIL+1))
    fi

    # 2. 配置文件检查
    if [ -f "$CONFIG" ]; then
        if [ -x "$CLASH_BIN" ]; then
            cfg_test=$($CLASH_BIN -f $CONFIG -t 2>&1)
            if echo "$cfg_test" | grep -qiE 'error|invalid|fail|panic'; then
                pl "  ${R}[FAIL]${N} 配置文件语法错误:"
                echo "$cfg_test" | head -5 | sed 's/^/    /'
                FAIL=$((FAIL+1))
            else
                CFG_SIZE=$(wc -c < "$CONFIG" 2>/dev/null)
                pl "  ${G}[PASS]${N} 配置文件有效 (${CFG_SIZE}B)"
                PASS=$((PASS+1))
            fi
        else
            pl "  ${Y}[WARN]${N} 配置文件存在但无法验证语法 (二进制不可用)"
            WARN=$((WARN+1))
        fi
    else
        pl "  ${R}[FAIL]${N} 配置文件不存在: $CONFIG"
        FAIL=$((FAIL+1))
    fi

    # 3. PID文件/进程检查
    PID=$(get_pid)
    if is_running; then
        pl "  ${G}[PASS]${N} 进程运行中 (PID:$PID)"
        PASS=$((PASS+1))
    elif [ -n "$PID" ]; then
        pl "  ${R}[FAIL]${N} PID文件存在($PID)但进程已死 (僵尸PID文件)"
        pl "    修复: rm -f $PID_FILE && cc start"
        FAIL=$((FAIL+1))
    else
        pl "  ${R}[FAIL]${N} 进程未运行"
        pl "    修复: cc start"
        FAIL=$((FAIL+1))
    fi

    # 4. 端口监听检查 (仅在运行时)
    if is_running; then
        pl "  ${C}── 端口监听 ──${N}"
        for p in 7890 7892 7893 9090 1053; do
            if netstat -tln 2>/dev/null | grep -q ":$p " || ss -tln 2>/dev/null | grep -q ":$p "; then
                pl "    ${G}[PASS]${N} 端口 $p 监听中"
                PASS=$((PASS+1))
            else
                pl "    ${R}[FAIL]${N} 端口 $p 未监听"
                FAIL=$((FAIL+1))
            fi
        done
    fi

    # 5. API响应检查
    if is_running; then
        api_result=$(api "/version" 2>/dev/null)
        if echo "$api_result" | grep -q "version"; then
            API_VER=$(echo "$api_result" | grep -oE '"version":"[^"]*"' | cut -d'"' -f4)
            pl "  ${G}[PASS]${N} API响应正常 (版本: ${API_VER:-?})"
            PASS=$((PASS+1))
        else
            pl "  ${R}[FAIL]${N} API无响应 (检查SECRET或端口9090)"
            FAIL=$((FAIL+1))
        fi
    fi

    # 6. DNS检查
    if is_running; then
        pl "  ${C}── DNS链路 ──${N}"
        if netstat -tuln 2>/dev/null | grep -q ':53 ' || ss -tuln 2>/dev/null | grep -q ':53 '; then
            pl "    ${G}[PASS]${N} dnsmasq:53 监听中"
            PASS=$((PASS+1))
        else
            pl "    ${R}[FAIL]${N} dnsmasq:53 未监听"
            FAIL=$((FAIL+1))
        fi
        if netstat -tuln 2>/dev/null | grep -q ':1053 ' || ss -tuln 2>/dev/null | grep -q ':1053 '; then
            pl "    ${G}[PASS]${N} clash-rs DNS:1053 监听中"
            PASS=$((PASS+1))
        else
            pl "    ${R}[FAIL]${N} clash-rs DNS:1053 未监听"
            FAIL=$((FAIL+1))
        fi
        dns_r=$(nslookup www.baidu.com 127.0.0.1 2>/dev/null | grep -A1 "Name:" | grep "Address" | head -1 | awk '{print $NF}')
        if [ -n "$dns_r" ]; then
            pl "    ${G}[PASS]${N} DNS解析正常 (baidu→$dns_r)"
            PASS=$((PASS+1))
        else
            pl "    ${R}[FAIL]${N} DNS解析失败"
            FAIL=$((FAIL+1))
        fi
    fi

    # 7. iptables规则检查
    if is_running; then
        pl "  ${C}── iptables规则 ──${N}"
        ipt_cnt=$(iptables -t nat -L clash_reroute -n 2>/dev/null | grep -c REDIRECT)
        if [ "${ipt_cnt:-0}" -gt 0 ]; then
            pl "    ${G}[PASS]${N} clash_reroute链 (${ipt_cnt}条REDIRECT规则)"
            PASS=$((PASS+1))
        else
            pl "    ${R}[FAIL]${N} clash_reroute链缺失或无规则 (透明代理不工作)"
            pl "      修复: cc restart"
            FAIL=$((FAIL+1))
        fi
        dns_cnt=$(iptables -t nat -L clash_dns -n 2>/dev/null | wc -l)
        if [ "${dns_cnt:-0}" -gt 2 ]; then
            pl "    ${G}[PASS]${N} clash_dns链 (${dns_cnt}行)"
            PASS=$((PASS+1))
        else
            pl "    ${Y}[WARN]${N} clash_dns链可能缺失 (DNS劫持不工作)"
            WARN=$((WARN+1))
        fi
        cn_cnt=$(ipset list cn_ip -t 2>/dev/null | grep "Number of entries" | awk '{print $4}')
        if [ "${cn_cnt:-0}" -gt 100 ]; then
            pl "    ${G}[PASS]${N} CN IP列表 (${cn_cnt}条)"
            PASS=$((PASS+1))
        else
            pl "    ${Y}[WARN]${N} CN IP列表过少 (${cn_cnt:-0}条, 建议 cc settings → 12 更新)"
            WARN=$((WARN+1))
        fi
    fi

    # 8. 内存检查
    if is_running; then
        pl "  ${C}── 内存 ──${N}"
        RSS=$(get_rss)
        MEM_LIMIT=$(get_mem_threshold_mb)
        HARD_LIMIT=$((MEM_LIMIT * 3 / 2))
        RSS_INT=$(echo "$RSS" | awk '{print int($1)}')
        if [ "$MEM_LIMIT" -gt 0 ] 2>/dev/null && [ "$RSS_INT" -gt "$HARD_LIMIT" ] 2>/dev/null; then
            pl "    ${R}[FAIL]${N} 内存超Hard限制: ${RSS}MB > ${HARD_LIMIT}MB"
            FAIL=$((FAIL+1))
        elif [ "$MEM_LIMIT" -gt 0 ] 2>/dev/null && [ "$RSS_INT" -gt "$MEM_LIMIT" ] 2>/dev/null; then
            pl "    ${Y}[WARN]${N} 内存超Soft限制: ${RSS}MB > ${MEM_LIMIT}MB (拒新连接)"
            WARN=$((WARN+1))
        else
            pl "    ${G}[PASS]${N} 内存正常: ${RSS}MB (Soft=${MEM_LIMIT}MB Hard=${HARD_LIMIT}MB)"
            PASS=$((PASS+1))
        fi
        MEM_AVAIL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $7/1024}')
        if [ "${MEM_AVAIL:-0}" -gt 30 ]; then
            pl "    ${G}[PASS]${N} 系统可用内存: ${MEM_AVAIL}MB"
            PASS=$((PASS+1))
        elif [ "${MEM_AVAIL:-0}" -gt 10 ]; then
            pl "    ${Y}[WARN]${N} 系统可用内存偏低: ${MEM_AVAIL}MB"
            WARN=$((WARN+1))
        else
            pl "    ${R}[FAIL]${N} 系统可用内存不足: ${MEM_AVAIL}MB"
            FAIL=$((FAIL+1))
        fi
    fi

    # 9. 看门狗检查
    if [ -f "$WATCHDOG_PID" ]; then
        if kill -0 $(cat $WATCHDOG_PID 2>/dev/null) 2>/dev/null; then
            pl "  ${G}[PASS]${N} 看门狗运行中 (PID:$(cat $WATCHDOG_PID))"
            PASS=$((PASS+1))
        else
            pl "  ${Y}[WARN]${N} 看门狗PID文件存在但进程已死 (僵尸PID文件)"
            pl "    修复: rm -f $WATCHDOG_PID"
            WARN=$((WARN+1))
        fi
    else
        pl "  ${Y}[INFO]${N} 看门狗未启用 (可选, cc settings → 4 开启)"
    fi

    # 10. init.d脚本检查
    if [ -f "$INIT_SCRIPT" ]; then
        pl "  ${G}[PASS]${N} init.d脚本存在"
        PASS=$((PASS+1))
    else
        pl "  ${R}[FAIL]${N} init.d脚本缺失: $INIT_SCRIPT"
        FAIL=$((FAIL+1))
    fi

    # 11. 开机自启检查
    if ls /etc/rc.d/S*clash-rs >/dev/null 2>&1; then
        pl "  ${G}[PASS]${N} 开机自启已设置"
        PASS=$((PASS+1))
    else
        pl "  ${Y}[WARN]${N} 未设置开机自启"
        WARN=$((WARN+1))
    fi

    # 汇总
    line
    TOTAL=$((PASS + WARN + FAIL))
    pl "${W}  诊断结果: ${G}${PASS} PASS${N} / ${Y}${WARN} WARN${N} / ${R}${FAIL} FAIL${N} (共${TOTAL}项)"
    if [ "$FAIL" -gt 0 ]; then
        pl "${R}  存在失败项, 请按提示修复${N}"
    elif [ "$WARN" -gt 0 ]; then
        pl "${Y}  存在警告项, 建议关注${N}"
    else
        pl "${G}  所有检查项通过${N}"
    fi
}

# ============================================================
# C13: 系统信息 (cc sysinfo)
# ============================================================
do_sysinfo() {
    pl "${C}  ═══ 系统信息 ═══${N}"
    line
    # 基本信息
    KERNEL=$(uname -r 2>/dev/null)
    ARCH=$(uname -m 2>/dev/null)
    HOSTNAME=$(cat /proc/sys/kernel/hostname 2>/dev/null)
    UPTIME_S=$(cat /proc/uptime 2>/dev/null | awk '{printf "%.0f", $1}')
    UPTIME_D=$((UPTIME_S / 86400))
    UPTIME_H=$(( (UPTIME_S % 86400) / 3600 ))
    UPTIME_M=$(( (UPTIME_S % 3600) / 60 ))
    LOADAVG=$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}')

    pl "  ${W}主机名${N}: $HOSTNAME"
    pl "  ${W}内核${N}: $KERNEL  ${W}架构${N}: $ARCH"
    pl "  ${W}系统运行${N}: ${UPTIME_D}天${UPTIME_H}时${UPTIME_M}分"
    pl "  ${W}负载${N}: $LOADAVG"

    # CPU信息
    pl "${C}  ── CPU ──${N}"
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
    [ -z "$CPU_MODEL" ] && CPU_MODEL=$(grep -m1 'Hardware' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ *//')
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo 2>/dev/null)
    CPU0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
    CPU1=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq 2>/dev/null)
    CPU0_MHZ="-"; CPU1_MHZ="-"
    [ -n "$CPU0" ] && CPU0_MHZ="$((CPU0/1000))MHz"
    [ -n "$CPU1" ] && CPU1_MHZ="$((CPU1/1000))MHz"
    GOV0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
    pl "  ${W}型号${N}: ${CPU_MODEL:-未知}"
    pl "  ${W}核心数${N}: ${CPU_CORES:-?}  ${W}频率${N}: ${CPU0_MHZ}/${CPU1_MHZ}  ${W}调度${N}: ${GOV0:-?}"

    # 温度
    T0=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
    T1=$(cat /sys/class/thermal/thermal_zone1/temp 2>/dev/null)
    T2=$(cat /sys/class/thermal/thermal_zone2/temp 2>/dev/null)
    [ "$T0" -gt 1000 ] 2>/dev/null && T0=$((T0/1000))
    [ "$T1" -gt 1000 ] 2>/dev/null && T1=$((T1/1000))
    [ "$T2" -gt 1000 ] 2>/dev/null && T2=$((T2/1000))
    pl "  ${W}温度${N} SoC:${T0:-?}°C  WiFi2.4:${T1:-?}°C  WiFi5:${T2:-?}°C"

    # 内存
    pl "${C}  ── 内存 ──${N}"
    MEM_TOTAL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $2/1024}')
    MEM_USED=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $3/1024}')
    MEM_AVAIL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $7/1024}')
    MEM_PCT=0
    [ "$MEM_TOTAL" -gt 0 ] 2>/dev/null && MEM_PCT=$((MEM_USED * 100 / MEM_TOTAL))
    SWAP_TOTAL=$(free 2>/dev/null | awk '/^Swap:/{printf "%.0f", $2/1024}')
    SWAP_USED=$(free 2>/dev/null | awk '/^Swap:/{printf "%.0f", $3/1024}')
    pl "  ${W}内存${N}: ${MEM_USED}MB/${MEM_TOTAL}MB (${MEM_PCT}%) 可用:${MEM_AVAIL}MB"
    pl "  ${W}Swap${N}: ${SWAP_USED:-0}MB/${SWAP_TOTAL:-0}MB"

    # 磁盘
    pl "${C}  ── 磁盘 ──${N}"
    df -h / 2>/dev/null | tail -1 | awk '{printf "  \033[1;37m/\033[0m 总:%s 用:%s (%s) 可:%s\n", $2, $3, $5, $4}'
    df -h /tmp 2>/dev/null | tail -1 | awk '{printf "  \033[1;37m/tmp\033[0m 总:%s 用:%s (%s) 可:%s\n", $2, $3, $5, $4}'
    df -h /overlay 2>/dev/null | tail -1 | awk '{printf "  \033[1;37m/overlay\033[0m 总:%s 用:%s (%s) 可:%s\n", $2, $3, $5, $4}'

    # 网络
    pl "${C}  ── 网络 ──${N}"
    ip a 2>/dev/null | grep -w 'inet' | grep 'global' | while read line; do
        iface=$(echo "$line" | awk '{print $NF}')
        ipaddr=$(echo "$line" | awk '{print $2}')
        pl "  ${W}${iface}${N}: $ipaddr"
    done
    GW=$(ip route 2>/dev/null | grep default | awk '{print $3}' | head -1)
    [ -n "$GW" ] && pl "  ${W}网关${N}: $GW"

    # NSS摘要
    pl "${C}  ── NSS加速 ──${N}"
    if [ -d /sys/kernel/debug/qca-nss-drv ]; then
        NSS_CPU=$(cat /sys/kernel/debug/qca-nss-drv/stats/cpu_load_ubi 2>/dev/null | grep -oE '[0-9]+%' | sed -n '2p')
        ECM=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count 2>/dev/null)
        pl "  ${W}驱动${N}: ${G}已加载${N}  ${W}CPU负载${N}: ${NSS_CPU:-?}  ${W}ECM连接${N}: ${ECM:-0}"
        pl "  ${Y}  详细信息: cc nss${N}"
    else
        pl "  ${R}NSS驱动未加载${N}"
    fi

    # clash-rs摘要
    pl "${C}  ── clash-rs ──${N}"
    if is_running; then
        PID=$(get_pid)
        RSS=$(get_rss)
        UPTIME=$(get_uptime)
        PROXY=$(get_proxy_now)
        pl "  ${W}状态${N}: ${G}运行中${N}  ${W}PID${N}: $PID  ${W}内存${N}: ${RSS}MB  ${W}运行${N}: $UPTIME"
        pl "  ${W}节点${N}: ${G}${PROXY:-未知}${N}"
    else
        pl "  ${W}状态${N}: ${R}未运行${N}"
    fi
    line
}

# ============================================================
# C12: NSS加速状态 (cc nss)
# ============================================================
do_nss() {
    pl "${C}  ═══ NSS 硬件加速状态 ═══${N}"
    line
    # 1. 驱动加载状态
    if [ -d /sys/kernel/debug/qca-nss-drv ]; then
        pl "  ${G}[PASS]${N} NSS驱动已加载 (qca-nss-drv)"
    else
        pl "  ${R}[FAIL]${N} NSS驱动未加载 (/sys/kernel/debug/qca-nss-drv 不存在)"
        pl "  ${Y}可能原因: 内核未编译NSS支持, 或驱动未加载${N}"
        return 1
    fi
    # 驱动模块
    NSS_MOD=$(lsmod 2>/dev/null | grep -E 'qca.nss|nss' | head -5)
    if [ -n "$NSS_MOD" ]; then
        pl "  ${C}已加载模块:${N}"
        echo "$NSS_MOD" | while read line; do
            pl "    $line"
        done
    fi

    # 2. NSS CPU负载
    pl "${C}  ── NSS CPU负载 ──${N}"
    NSS_CPU=$(cat /sys/kernel/debug/qca-nss-drv/stats/cpu_load_ubi 2>/dev/null)
    if [ -n "$NSS_CPU" ]; then
        echo "$NSS_CPU" | head -5 | while read line; do
            pl "  $line"
        done
    else
        pl "  ${Y}无法读取CPU负载${N}"
    fi

    # 3. 包统计 (n2h)
    pl "${C}  ── 包统计 (N2H) ──${N}"
    NSS_STATS=$(cat /sys/kernel/debug/qca-nss-drv/stats/n2h 2>/dev/null)
    if [ -n "$NSS_STATS" ]; then
        rx_pkts=$(echo "$NSS_STATS" | grep "n2h_rx_pkts" | awk '{print $3}')
        tx_pkts=$(echo "$NSS_STATS" | grep "n2h_tx_pkts" | awk '{print $3}')
        rx_drop=$(echo "$NSS_STATS" | grep "n2h_rx_drops" | awk '{print $3}')
        tx_drop=$(echo "$NSS_STATS" | grep "n2h_tx_drops" | awk '{print $3}')
        pl "  ${W}RX包${N}: ${rx_pkts:-0}  ${W}TX包${N}: ${tx_pkts:-0}"
        pl "  ${W}RX丢包${N}: ${rx_drop:-0}  ${W}TX丢包${N}: ${tx_drop:-0}"
    else
        pl "  ${Y}无法读取N2H统计${N}"
    fi

    # 4. ECM状态
    pl "${C}  ── ECM (Edge Connection Manager) ──${N}"
    if [ -d /sys/kernel/debug/ecm ]; then
        ECM_CNT=$(cat /sys/kernel/debug/ecm/ecm_db/connection_count 2>/dev/null)
        pl "  ${W}活跃连接${N}: ${ECM_CNT:-0}"
        ECM_STATE=$(cat /sys/kernel/debug/ecm/ecm_db/state 2>/dev/null | head -1)
        [ -n "$ECM_STATE" ] && pl "  ${W}状态${N}: $ECM_STATE"
    else
        pl "  ${R}ECM未加载${N}"
    fi

    # 5. conntrack
    pl "${C}  ── 连接跟踪 ──${N}"
    CONN=$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)
    CONN_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)
    CONN_PCT=0
    [ "$CONN_MAX" -gt 0 ] 2>/dev/null && CONN_PCT=$((CONN * 100 / CONN_MAX))
    pl "  ${W}conntrack${N}: ${CONN:-0}/${CONN_MAX:-0} (${CONN_PCT}%)"

    # 6. 网络接口
    pl "${C}  ── 加速接口 ──${N}"
    for iface in eth0 eth1 ath0 ath1 br-lan; do
        if [ -d "/sys/class/net/$iface" ]; then
            RX=$(cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null)
            TX=$(cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null)
            if [ "$RX" -gt 1048576 ] 2>/dev/null; then
                RX_S="$(awk "BEGIN{printf \"%.1f\", $RX/1048576}")MB"
            else
                RX_S="${RX}B"
            fi
            if [ "$TX" -gt 1048576 ] 2>/dev/null; then
                TX_S="$(awk "BEGIN{printf \"%.1f\", $TX/1048576}")MB"
            else
                TX_S="${TX}B"
            fi
            pl "  ${W}${iface}${N}: RX=${RX_S} TX=${TX_S}"
        fi
    done
    line
}

# ============================================================
# 进程资源详情 (cc top)
# ============================================================
do_top() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi
    PID=$(get_pid)
    pl "${C}  === clash-rs 进程资源详情 ===${N}"
    # 基本信息从/proc/PID/status
    RSS=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2}')
    VMS=$(grep VmSize /proc/$PID/status 2>/dev/null | awk '{print $2}')
    THREADS=$(grep Threads /proc/$PID/status 2>/dev/null | awk '{print $2}')
    SWAP=$(grep VmSwap /proc/$PID/status 2>/dev/null | awk '{print $2}')
    # CPU使用率(从/proc/stat两次采样)
    s1_total=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat 2>/dev/null)
    s1_idle=$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null)
    # 进程CPU时间
    p1_utime=$(awk '{print $14}' /proc/$PID/stat 2>/dev/null)
    p1_stime=$(awk '{print $15}' /proc/$PID/stat 2>/dev/null)
    sleep 1
    s2_total=$(awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat 2>/dev/null)
    s2_idle=$(awk '/^cpu /{print $5}' /proc/stat 2>/dev/null)
    p2_utime=$(awk '{print $14}' /proc/$PID/stat 2>/dev/null)
    p2_stime=$(awk '{print $15}' /proc/$PID/stat 2>/dev/null)
    cpu_pct=0
    proc_pct=0
    d_total=$((s2_total - s1_total))
    d_idle=$((s2_idle - s1_idle))
    d_proc=$(( (p2_utime + p2_stime) - (p1_utime + p1_stime) ))
    [ "$d_total" -gt 0 ] 2>/dev/null && cpu_pct=$(( 100 * (d_total - d_idle) / d_total ))
    # B12: 简化公式 (d_proc*100*100/d_total/100 等价于 d_proc*100/d_total, 减少溢出风险)
    [ "$d_total" -gt 0 ] 2>/dev/null && proc_pct=$(( d_proc * 100 / d_total ))
    # FD数量
    FD_CNT=$(ls /proc/$PID/fd 2>/dev/null | wc -l)
    FD_MAX=$(cat /proc/$PID/limits 2>/dev/null | grep 'open files' | awk '{print $4}')
    # 网络连接数 (netstat -tn 无 -p 不显示PID, 直接从 /proc 读取)
    CONN_CNT=$(cat /proc/$PID/net/sockstat 2>/dev/null | grep TCP: | awk '{print $3}')
    pl "  ${W}PID${N}: $PID  ${W}线程${N}: ${THREADS:-?}  ${W}CPU${N}: ${cpu_pct}% (进程:${proc_pct}%)"
    pl "  ${W}RSS${N}: $((RSS/1024))MB  ${W}虚拟内存${N}: $((VMS/1024))MB  ${W}Swap${N}: $((SWAP/1024))MB"
    pl "  ${W}FD${N}: ${FD_CNT}/${FD_MAX:-?}  ${W}TCP连接${N}: ${CONN_CNT:-?}"
    # 上下文切换
    CTX_SW=$(cat /proc/$PID/status 2>/dev/null | grep -E 'voluntary_ctxt|nonvoluntary_ctxt' | awk '{s+=$2} END{print s}')
    [ -n "$CTX_SW" ] && pl "  ${W}上下文切换${N}: ${CTX_SW}"
    # 内存映射前5
    pl "${C}  内存映射TOP5:${N}"
    if [ -f /proc/$PID/smaps ]; then
        cat /proc/$PID/smaps 2>/dev/null | awk '/^[0-9a-f]/{name=$NF} /^Rss:/{rss[name]+=$2} END{for(n in rss) printf "%8d kB  %s\n", rss[n], n}' | sort -rn | head -5 | while read line; do
            pl "    $line"
        done
    elif [ -f /proc/$PID/maps ]; then
        cat /proc/$PID/maps 2>/dev/null | awk '{print $NF}' | sort | uniq -c | sort -rn | head -5 | while read line; do
            pl "    $line"
        done
    else
        pl "    ${Y}(此内核不支持smaps)${N}"
    fi
}

# ============================================================
# 网速测试 (cc speed)
# ============================================================
do_speed() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi
    pl "${C}  === 网速测试 ===${N}"
    # S3: 更新测速URL (Cloudflare 5MB→10MB, Google Android Studio→Chrome稳定版)
    # [1/3] 直连测速 (国外CDN)
    pl "${Y}  [1/3] 直连测速(国外CDN 1MB)...${N}"
    r1=$(curl -s -o /dev/null -w '%{speed_download} %{time_total}' --connect-timeout 5 --max-time 15 http://speedtest.tele2.net/1MB.zip 2>/dev/null)
    sp1=$(echo "$r1" | awk '{print $1}')
    t1=$(echo "$r1" | awk '{print $2}')
    if [ -n "$sp1" ] && [ "$sp1" -gt 0 ] 2>/dev/null; then
        pl "  ${G}直连${N}: $(_fmt_bytes "${sp1%.*}")/s (${t1}s)"
    else
        pl "  ${R}直连测速失败${N}"
    fi
    # [2/3] 代理测速 (Cloudflare 10MB)
    pl "${Y}  [2/3] 代理测速(Cloudflare 10MB)...${N}"
    r2=$(curl -s -o /dev/null -w '%{speed_download} %{time_total}' --connect-timeout 5 --max-time 25 -x http://127.0.0.1:7890 "https://speed.cloudflare.com/__down?bytes=10000000" 2>/dev/null)
    sp2=$(echo "$r2" | awk '{print $1}')
    t2=$(echo "$r2" | awk '{print $2}')
    if [ -n "$sp2" ] && [ "$sp2" -gt 0 ] 2>/dev/null; then
        pl "  ${G}代理CF${N}: $(_fmt_bytes "${sp2%.*}")/s (${t2}s)"
    else
        pl "  ${R}代理Cloudflare测速失败${N}"
    fi
    # [3/3] 代理测速 (Google Chrome 稳定版下载, 大文件可持续测速)
    pl "${Y}  [3/3] 代理测速(Google 20MB)...${N}"
    r3=$(curl -s -o /dev/null -w '%{speed_download} %{time_total}' --connect-timeout 5 --max-time 20 -x http://127.0.0.1:7890 "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" 2>/dev/null)
    sp3=$(echo "$r3" | awk '{print $1}')
    t3=$(echo "$r3" | awk '{print $2}')
    if [ -n "$sp3" ] && [ "$sp3" -gt 0 ] 2>/dev/null; then
        pl "  ${G}代理Google${N}: $(_fmt_bytes "${sp3%.*}")/s (${t3}s)"
    else
        pl "  ${R}代理Google测速失败${N}"
    fi
}

# ============================================================
# 连接列表 (cc conn)
# ============================================================
do_conn() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return
    fi
    pl "${C}  === clash-rs 活跃连接 (TOP20 按下载排序) ===${N}"
    data=$(curl -s -H "Authorization: Bearer $SECRET" "http://${API_HOST}:${API_PORT}/connections" 2>/dev/null)
    if [ -z "$data" ]; then
        pl "${R}  获取连接失败${N}"
        return
    fi
    # B6: 顶层统计 (这些字段只在顶层出现, grep可靠)
    total=$(echo "$data" | grep -o '"id":"' | wc -l)
    up_total=$(echo "$data" | grep -o '"uploadTotal":[0-9]*' | head -1 | cut -d: -f2)
    down_total=$(echo "$data" | grep -o '"downloadTotal":[0-9]*' | head -1 | cut -d: -f2)
    pl "  ${W}总连接${N}: $total  ${W}总上传${N}: $(_fmt_bytes "$up_total")  ${W}总下载${N}: $(_fmt_bytes "$down_total")"
    pl "${C}  ───────────────────────────────────────${N}"
    # B6: 用awk单次解析每个连接字段 (替代6个grep/sed fork, 修复chains的->显示)
    # 输出: 下载量|主机|网络|链|规则|上传量  (sort -rn按下载量排序)
    echo "$data" | sed 's/},{/}\n{/g' | grep '"host"' | awk '
    {
        host = ""; network = ""; chains = ""; rule = ""; dl = 0; ul = 0
        if (match($0, /"host":"[^"]*"/))
            host = substr($0, RSTART+8, RLENGTH-9)
        if (match($0, /"network":"[^"]*"/))
            network = substr($0, RSTART+11, RLENGTH-12)
        if (match($0, /"chains":\[/)) {
            chains = substr($0, RSTART+10)
            end = index(chains, "]")
            if (end > 0) chains = substr(chains, 1, end-1)
            gsub(/"/, "", chains)
            gsub(/,/, "->", chains)
        }
        if (match($0, /"rule":"[^"]*"/))
            rule = substr($0, RSTART+8, RLENGTH-9)
        if (match($0, /"download":[0-9]+/))
            dl = substr($0, RSTART+11, RLENGTH-11)
        if (match($0, /"upload":[0-9]+/))
            ul = substr($0, RSTART+9, RLENGTH-9)
        if (host != "")
            printf "%d|%s|%s|%s|%s|%d\n", dl+0, host, network, chains, rule, ul+0
    }' | sort -rn | head -20 | while IFS='|' read dl host net chain rule ul; do
        pl "  ${G}${host}${N} [${net}] ${Y}↓$(_fmt_bytes "$dl") ↑$(_fmt_bytes "$ul")${N} -> ${C}${chain}${N} (${rule})"
    done
}

# ============================================================
# v4.6 批次8: API热修改能力
# ============================================================

# 查看运行时配置 (GET /configs)
# 用法: cc apiconf
# 功能: 从clash-rs API拉取当前生效的运行时配置并美化显示, 包括:
#   - 各代理端口 (HTTP/SOCKS5/REDIRECT/TPROXY/混合)
#   - 运行模式 (rule规则分流/global全部代理/direct全部直连)
#   - 日志级别 / IPv6开关 / 允许局域网 / 绑定地址
# 用途: 快速确认当前运行状态, 配合 cc patch 热修改字段
do_apiconf() {
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    local data
    data=$(curl -s -H "Authorization: Bearer $SECRET" "http://${API_HOST}:${API_PORT}/configs" 2>/dev/null)
    if [ -z "$data" ]; then
        pl "${R}  获取运行时配置失败${N}"
        return 1
    fi
    pl "${C}  === clash-rs 运行时配置 (GET /configs) ===${N}"
    line
    # 提取并美化显示关键字段
    local port socks redir tproxy mixed mode loglvl ipv6 allowlan bind
    port=$(echo "$data" | grep -oE '"port":[0-9]+' | head -1 | cut -d: -f2)
    socks=$(echo "$data" | grep -oE '"socks-port":[0-9]+' | head -1 | cut -d: -f2)
    redir=$(echo "$data" | grep -oE '"redir-port":[0-9]+' | head -1 | cut -d: -f2)
    tproxy=$(echo "$data" | grep -oE '"tproxy-port":[0-9]+' | head -1 | cut -d: -f2)
    mixed=$(echo "$data" | grep -oE '"mixed-port":[0-9]+' | head -1 | cut -d: -f2)
    mode=$(echo "$data" | grep -oE '"mode":"[^"]*"' | head -1 | cut -d: -f2 | tr -d '"')
    loglvl=$(echo "$data" | grep -oE '"log-level":"[^"]*"' | head -1 | cut -d: -f2 | tr -d '"')
    ipv6=$(echo "$data" | grep -oE '"ipv6":(true|false)' | head -1 | cut -d: -f2)
    allowlan=$(echo "$data" | grep -oE '"allow-lan":(true|false)' | head -1 | cut -d: -f2)
    bind=$(echo "$data" | grep -oE '"bind-address":"[^"]*"' | head -1 | cut -d: -f2 | tr -d '"')
    pl "  ${W}HTTP代理端口${N}:   ${G}${port:-未设置}${N}"
    pl "  ${W}SOCKS5端口${N}:     ${G}${socks:-未设置}${N}"
    pl "  ${W}REDIRECT端口${N}:   ${G}${redir:-未设置}${N}"
    pl "  ${W}TPROXY端口${N}:     ${G}${tproxy:-未设置}${N}"
    pl "  ${W}混合端口${N}:       ${G}${mixed:-未设置}${N}"
    pl "  ${W}运行模式${N}:       ${G}${mode:-未知}${N}  (rule/global/direct)"
    pl "  ${W}日志级别${N}:       ${G}${loglvl:-未知}${N}  (trace/debug/info/warning/error/silent)"
    pl "  ${W}IPv6${N}:           ${G}${ipv6:-未知}${N}"
    pl "  ${W}允许局域网${N}:     ${G}${allowlan:-未知}${N}"
    pl "  ${W}绑定地址${N}:       ${G}${bind:-未知}${N}"
    line
    pl "${Y}  提示: cc patch <field> <value> 可热修改上述字段${N}"
    pl "${Y}  例如: cc patch mode global / cc patch ipv6 true / cc patch port 7891${N}"
}

# 热修改运行时配置 (PATCH /configs)
# 用法: cc patch <field> <value>
# 功能: 通过API热修改clash-rs运行时字段, 同时持久化到 config.yaml
#   - 端口类: port/socks-port/redir-port/tproxy-port/mixed-port (1-65535)
#   - mode: rule(规则分流) / global(全部代理) / direct(全部直连)
#   - log-level: trace/debug/info/warning/error/silent
#   - ipv6 / allow-lan: true/false 开关
#   - bind-address: 绑定地址 (* / localhost / [::] / IP)
# 特点: 先热生效(无需重启), 再写回config.yaml持久化; 含字段白名单校验
# 用途: 临时切换模式/调试日志级别/改端口, 避免重启断网
do_patch() {
    local field="$1" value="$2"
    if [ -z "$field" ]; then
        pl "${R}  用法: cc patch <field> <value>${N}"
        pl "  支持字段:"
        pl "    ${W}port${N}          HTTP代理端口 (1-65535)"
        pl "    ${W}socks-port${N}    SOCKS5端口"
        pl "    ${W}redir-port${N}    REDIRECT端口"
        pl "    ${W}tproxy-port${N}   TPROXY端口"
        pl "    ${W}mixed-port${N}    混合端口"
        pl "    ${W}mode${N}          模式 (rule/global/direct)"
        pl "    ${W}log-level${N}     日志级别 (trace/debug/info/warning/error/silent)"
        pl "    ${W}ipv6${N}          IPv6开关 (true/false)"
        pl "    ${W}allow-lan${N}     允许局域网 (true/false)"
        pl "    ${W}bind-address${N}  绑定地址 (* / localhost / [::] / IP)"
        return 1
    fi
    if [ -z "$value" ]; then
        pl "${R}  请提供新值${N}"
        return 1
    fi
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    # 字段白名单校验
    case "$field" in
        port|socks-port|redir-port|tproxy-port|mixed-port)
            case "$value" in
                ''|*[!0-9]*) pl "${R}  端口必须为数字${N}"; return 1 ;;
            esac
            if [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
                pl "${R}  端口范围 1-65535${N}"
                return 1
            fi
            ;;
        mode)
            case "$value" in
                rule|global|direct) ;;
                *) pl "${R}  mode 可选: rule/global/direct${N}"; return 1 ;;
            esac
            ;;
        log-level)
            case "$value" in
                trace|debug|info|warning|error|silent) ;;
                *) pl "${R}  log-level 可选: trace/debug/info/warning/error/silent${N}"; return 1 ;;
            esac
            ;;
        ipv6|allow-lan)
            case "$value" in
                true|false) ;;
                *) pl "${R}  ${field} 可选: true/false${N}"; return 1 ;;
            esac
            ;;
        bind-address) ;;
        *)
            pl "${R}  不支持的字段: ${field}${N}"
            pl "  运行 cc patch 查看支持字段"
            return 1
            ;;
    esac
    # 构造JSON payload (字符串值需加引号, 数字/布尔不加)
    local payload
    case "$value" in
        true|false|''|*[!0-9]*)
            payload="{\"${field}\":\"${value}\"}"
            ;;
        *)
            payload="{\"${field}\":${value}}"
            ;;
    esac
    pl "${C}  热修改 ${field} -> ${value} ...${N}"
    local result
    result=$(curl -s -X PATCH -H "Authorization: Bearer $SECRET" -H "Content-Type: application/json" \
        -d "$payload" "http://${API_HOST}:${API_PORT}/configs" 2>/dev/null)
    if [ -n "$result" ] && echo "$result" | grep -qiE 'error|invalid|forbidden'; then
        pl "${R}  API返回错误: ${result}${N}"
        return 1
    fi
    sleep 1
    # 持久化到 config.yaml (修改顶层字段)
    if grep -qE "^${field}:" "$CONFIG" 2>/dev/null; then
        # 字符串值用引号, 数字/布尔不加
        case "$value" in
            true|false|''|*[!0-9]*)
                # 字符串: 若是纯字母数字/IP/* 不加引号, 否则加引号
                case "$value" in
                    rule|global|direct|trace|debug|info|warning|error|silent|true|false|localhost|\*)
                        sed -i "s|^${field}:.*|${field}: ${value}|" "$CONFIG" 2>/dev/null
                        ;;
                    *)
                        sed -i "s|^${field}:.*|${field}: \"${value}\"|" "$CONFIG" 2>/dev/null
                        ;;
                esac
                ;;
            *)
                sed -i "s|^${field}:.*|${field}: ${value}|" "$CONFIG" 2>/dev/null
                ;;
        esac
        pl "${G}  已持久化到 config.yaml${N}"
    else
        pl "${Y}  字段 ${field} 不在 config.yaml 顶层, 仅热生效 (重启后丢失)${N}"
    fi
    pl "${G}  ${field} 已热修改为 ${value}${N}"
}

# 关闭连接 (DELETE /connections or /connections/{id})
# 用法: cc conns kill <id|all>
# 功能: 强制关闭指定连接或全部连接
#   - kill <id>: 关闭指定UUID连接 (先用 cc conn 查看取id字段)
#   - kill all:  关闭所有连接 (会断开当前所有代理流量, 需确认)
# 用途: 节点切换后清理残留连接 / 排查异常长连接 / 强制重连
do_conns_kill() {
    local target="$1"
    if [ -z "$target" ]; then
        pl "${R}  用法: cc conns kill <id|all>${N}"
        pl "  先用 cc conn 查看连接, 取 id 字段"
        return 1
    fi
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    if [ "$target" = "all" ]; then
        pl "${Y}  即将关闭所有连接, 确认? (y/N)${N}"
        printf "  > "
        read confirm
        case "$confirm" in
            y|Y) ;;
            *) pl "  已取消"; return 0 ;;
        esac
        local result
        result=$(curl -s -X DELETE -H "Authorization: Bearer $SECRET" \
            "http://${API_HOST}:${API_PORT}/connections" 2>/dev/null)
        pl "${G}  已发送关闭所有连接指令${N}"
    else
        # 校验id格式 (UUID)
        local result
        result=$(curl -s -X DELETE -H "Authorization: Bearer $SECRET" \
            "http://${API_HOST}:${API_PORT}/connections/${target}" 2>/dev/null)
        if [ -n "$result" ] && echo "$result" | grep -qiE 'error|not found'; then
            pl "${R}  关闭失败: ${result}${N}"
            return 1
        fi
        pl "${G}  已关闭连接: ${target}${N}"
    fi
}

# 查看路由规则 (GET /rules)
# 用法: cc rules [N]  N=显示前N条, 默认50
# 功能: 拉取clash-rs当前加载的路则列表, 显示每条规则的:
#   - 类型 (DOMAIN/IP-CIDR/GEOIP/PROCESS-NAME/MATCH等)
#   - 载体 (匹配的域名/IP/进程名等)
#   - 出口 (PROXY/DIRECT/REJECT或具体节点组名)
# 用途: 排查"为什么某网站走代理/直连" / 确认规则加载顺序 / 规则集是否生效
# 注意: 规则在 config.yaml 的 rules: 段定义, cc patch 不能改规则
do_rules() {
    local limit="${1:-50}"
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    local data
    data=$(curl -s -H "Authorization: Bearer $SECRET" "http://${API_HOST}:${API_PORT}/rules" 2>/dev/null)
    if [ -z "$data" ]; then
        pl "${R}  获取规则失败${N}"
        return 1
    fi
    local total
    total=$(echo "$data" | grep -o '"type"' | wc -l)
    pl "${C}  === clash-rs 路由规则 (共 ${total} 条, 显示前 ${limit}) ===${N}"
    line
    pl "  ${W}序号  类型              载体                    代理${N}"
    line
    echo "$data" | sed 's/},{/}\n{/g' | grep '"type"' | head -"$limit" | awk '
    {
        type = ""; payload = ""; proxy = ""
        if (match($0, /"type":"[^"]*"/))
            type = substr($0, RSTART+8, RLENGTH-9)
        if (match($0, /"payload":"[^"]*"/))
            payload = substr($0, RSTART+11, RLENGTH-12)
        if (match($0, /"proxy":"[^"]*"/))
            proxy = substr($0, RSTART+9, RLENGTH-10)
        printf "%-6s %-18s %-24s %s\n", NR, type, payload, proxy
    }'
    line
    pl "${Y}  提示: 完整规则在 config.yaml 的 rules: 段, cc patch 不能改规则${N}"
}

# DNS解析测试 (GET /dns/query?name=&type=)
# 用法: cc dns-query <domain> [type]
# 功能: 通过clash-rs内置DNS解析域名, 显示应答记录(名称/类型/TTL/数据)
#   - type: A(IPv4) / AAAA(IPv6) / CNAME(别名) / MX(邮件) / TXT / NS / SOA, 默认A
# 用途: 验证clash-rs DNS是否正常工作 / 排查fake-ip污染 / 对比系统DNS结果
# 注意: 走的是clash-rs的DNS(1053), 不是系统DNS; 需clash-rs运行且DNS已启用
do_dns_query() {
    local name="$1" qtype="${2:-A}"
    if [ -z "$name" ]; then
        pl "${R}  用法: cc dns-query <domain> [type]${N}"
        pl "  type 可选: A/AAAA/CNAME/MX/TXT/NS/SOA (默认 A)"
        return 1
    fi
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    pl "${C}  DNS 查询: ${name} (${qtype})${N}"
    local data
    data=$(curl -s -H "Authorization: Bearer $SECRET" \
        "http://${API_HOST}:${API_PORT}/dns/query?name=${name}&type=${qtype}" 2>/dev/null)
    if [ -z "$data" ]; then
        pl "${R}  DNS 查询失败 (clash-rs DNS未启用或查询失败)${N}"
        return 1
    fi
    if echo "$data" | grep -qiE 'error|not found'; then
        pl "${R}  DNS 查询错误: ${data}${N}"
        return 1
    fi
    line
    # 提取 Answer 段
    if echo "$data" | grep -q '"Answer"'; then
        pl "  ${W}应答记录:${N}"
        echo "$data" | sed 's/},{/}\n{/g' | grep '"data"' | awk '
        {
            name=""; ttl=""; rdata=""; rtype=""; tname=""
            if (match($0, /"name":"[^"]*"/))
                name = substr($0, RSTART+8, RLENGTH-9)
            if (match($0, /"ttl":[0-9]+/))
                ttl = substr($0, RSTART+6, RLENGTH-6)
            if (match($0, /"data":"[^"]*"/))
                rdata = substr($0, RSTART+8, RLENGTH-9)
            if (match($0, /"type":[0-9]+/))
                rtype = substr($0, RSTART+7, RLENGTH-7)
            # DNS记录类型 数字转可读名称 (busybox awk 用 if/else 链, 不用 switch)
            tname = rtype
            if (rtype == "1") tname = "A"
            else if (rtype == "28") tname = "AAAA"
            else if (rtype == "5") tname = "CNAME"
            else if (rtype == "15") tname = "MX"
            else if (rtype == "16") tname = "TXT"
            else if (rtype == "2") tname = "NS"
            else if (rtype == "6") tname = "SOA"
            else if (rtype == "12") tname = "PTR"
            if (rdata != "")
                printf "    %-22s %-6s TTL=%-6s %s\n", name, tname, ttl, rdata
        }'
    else
        pl "${Y}  无应答 (可能域名不存在或被fake-ip)${N}"
        pl "  原始返回: $data"
    fi
    line
}

# 流向聚合TOP (GET /flows?top=&include_closed=)
# 用法: cc flows [N]  N=TOP数, 默认15
# 功能: 按目标主机:端口聚合统计流量, 显示每条的:
#   - 目标主机:端口 / 协议(TCP/UDP)
#   - 下载字节数 / 上传字节数 / 连接数
# 用途: 发现高流量目标 / 排查带宽占用 / 确认流量走向代理还是直连
do_flows() {
    local top="${1:-15}"
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    local data
    data=$(curl -s -H "Authorization: Bearer $SECRET" \
        "http://${API_HOST}:${API_PORT}/flows?top=${top}&include_closed=true" 2>/dev/null)
    if [ -z "$data" ]; then
        pl "${R}  获取流向失败${N}"
        return 1
    fi
    pl "${C}  === 流量流向 TOP${top} ===${N}"
    line
    pl "  ${W}目标主机/端口          协议  下载        上传        连接数${N}"
    line
    echo "$data" | sed 's/},{/}\n{/g' | grep -E '"host"|"download"' | awk '
    {
        host=""; port=""; proto=""; dl=0; ul=0; cnt=0
        if (match($0, /"host":"[^"]*"/))
            host = substr($0, RSTART+8, RLENGTH-9)
        if (match($0, /"destinationPort":[0-9]+/))
            port = substr($0, RSTART+18, RLENGTH-18)
        if (match($0, /"network":"[^"]*"/))
            proto = substr($0, RSTART+11, RLENGTH-12)
        if (match($0, /"download":[0-9]+/))
            dl = substr($0, RSTART+11, RLENGTH-11)
        if (match($0, /"upload":[0-9]+/))
            ul = substr($0, RSTART+9, RLENGTH-9)
        if (match($0, /"count":[0-9]+/))
            cnt = substr($0, RSTART+8, RLENGTH-8)
        if (host != "")
            printf "%-24s %-6s %-11s %-11s %s\n", host":"port, proto, dl, ul, cnt
    }' | head -"$top"
    line
    pl "${Y}  说明: 用于定位高带宽流量来源, 按 host:port 聚合${N}"
}

# ============================================================
# v4.6 批次10: 子菜单管理
# ============================================================

# providers管理 (代理集/规则集)
# 用法: cc provider [list|update <name>|update all]
# 功能: 管理clash-rs的proxy-providers和rule-providers
#   - list:   列出所有代理集(订阅)和规则集, 显示名称/类型/来源
#   - update <name>: 触发指定提供器更新(先试代理集再试规则集)
#   - update all:    触发全部提供器更新
# 用途: 订阅更新后强制刷新节点 / 规则集过期后重新拉取 / 排查提供器加载失败
do_provider() {
    local sub="${1:-list}"
    if ! is_running; then
        pl "${R}  clash-rs 未运行${N}"
        return 1
    fi
    case "$sub" in
        list|"")
            local data
            data=$(curl -s -H "Authorization: Bearer $SECRET" \
                "http://${API_HOST}:${API_PORT}/providers/proxies" 2>/dev/null)
            local data_r
            data_r=$(curl -s -H "Authorization: Bearer $SECRET" \
                "http://${API_HOST}:${API_PORT}/providers/rules" 2>/dev/null)
            pl "${C}  === 代理集 (proxy-providers) ===${N}"
            line
            if [ -z "$data" ] || echo "$data" | grep -q '"providers":{}'; then
                pl "${Y}  无代理集${N}"
            else
                echo "$data" | sed 's/},{/}\n{/g' | grep -E '"name"|"type"|"vehicleType"' | awk '
                {
                    name=""; type=""; veh=""
                    if (match($0, /"name":"[^"]*"/)) name = substr($0, RSTART+8, RLENGTH-9)
                    if (match($0, /"type":"[^"]*"/)) type = substr($0, RSTART+8, RLENGTH-9)
                    if (match($0, /"vehicleType":"[^"]*"/)) veh = substr($0, RSTART+15, RLENGTH-16)
                    if (name != "" && name !~ /^provid/) printf "  %-20s %-10s %s\n", name, type, veh
                }'
            fi
            line
            pl "${C}  === 规则集 (rule-providers) ===${N}"
            line
            if [ -z "$data_r" ] || echo "$data_r" | grep -q '"providers":{}'; then
                pl "${Y}  无规则集${N}"
            else
                echo "$data_r" | sed 's/},{/}\n{/g' | grep -E '"name"|"type"|"behavior"' | awk '
                {
                    name=""; type=""; beh=""
                    if (match($0, /"name":"[^"]*"/)) name = substr($0, RSTART+8, RLENGTH-9)
                    if (match($0, /"type":"[^"]*"/)) type = substr($0, RSTART+8, RLENGTH-9)
                    if (match($0, /"behavior":"[^"]*"/)) beh = substr($0, RSTART+12, RLENGTH-13)
                    if (name != "" && name !~ /^provid/) printf "  %-20s %-10s %s\n", name, type, beh
                }'
            fi
            line
            pl "${Y}  提示: cc provider update <name> 触发更新, update all 更新全部${N}"
            ;;
        update)
            local name="$2"
            if [ -z "$name" ]; then
                pl "${R}  用法: cc provider update <name|all>${N}"
                return 1
            fi
            if [ "$name" = "all" ]; then
                pl "${C}  触发更新所有代理集与规则集...${N}"
                # 代理集
                local data
                data=$(curl -s -H "Authorization: Bearer $SECRET" \
                    "http://${API_HOST}:${API_PORT}/providers/proxies" 2>/dev/null)
                echo "$data" | grep -oE '"name":"[^"]*"' | cut -d: -f2 | tr -d '"' | while read pn; do
                    [ -z "$pn" ] || [ "$pn" = "providers" ] && continue
                    curl -s -X PUT -H "Authorization: Bearer $SECRET" \
                        "http://${API_HOST}:${API_PORT}/providers/proxies/${pn}" >/dev/null 2>&1
                    pl "  ${G}代理集 ${pn} 已触发更新${N}"
                done
                # 规则集
                data=$(curl -s -H "Authorization: Bearer $SECRET" \
                    "http://${API_HOST}:${API_PORT}/providers/rules" 2>/dev/null)
                echo "$data" | grep -oE '"name":"[^"]*"' | cut -d: -f2 | tr -d '"' | while read rn; do
                    [ -z "$rn" ] || [ "$rn" = "providers" ] && continue
                    curl -s -X PUT -H "Authorization: Bearer $SECRET" \
                        "http://${API_HOST}:${API_PORT}/providers/rules/${rn}" >/dev/null 2>&1
                    pl "  ${G}规则集 ${rn} 已触发更新${N}"
                done
            else
                # 尝试先代理集后规则集
                local r1 r2
                r1=$(curl -s -X PUT -H "Authorization: Bearer $SECRET" \
                    "http://${API_HOST}:${API_PORT}/providers/proxies/${name}" 2>/dev/null)
                if echo "$r1" | grep -qiE 'not found|error'; then
                    r2=$(curl -s -X PUT -H "Authorization: Bearer $SECRET" \
                        "http://${API_HOST}:${API_PORT}/providers/rules/${name}" 2>/dev/null)
                    if echo "$r2" | grep -qiE 'not found|error'; then
                        pl "${R}  未找到提供器: ${name}${N}"
                        return 1
                    fi
                    pl "${G}  规则集 ${name} 已触发更新${N}"
                else
                    pl "${G}  代理集 ${name} 已触发更新${N}"
                fi
            fi
            ;;
        *)
            pl "${R}  用法: cc provider [list|update <name|all>]${N}"
            return 1
            ;;
    esac
}

# TUN配置子菜单 (config.yaml 的 tun: 段)
# 用法: cc tun
# 功能: 交互式管理TUN虚拟网卡配置, 修改后自动备份+热重载+失败回滚
#   - enable:        TUN开关 (true/false), 开启后接管全局流量
#   - device:        虚拟网卡名 (默认utun1989)
#   - gateway:       网关CIDR (默认198.18.0.1/24)
#   - mtu:           最大传输单元 (默认1500, PPPoE环境建议1492)
#   - dns-hijack:    DNS劫持开关 (拦截DNS请求交由clash-rs处理)
# 用途: 需要接管全局流量(含非代理程序) / 替代iptables透明代理 / 调试TUN模式
# 注意: 需内核tun模块支持 (/dev/net/tun); 改enable会热重载, 短暂断网
do_tun() {
    while true; do
        # 读取当前TUN配置
        local tun_enable="未设置"
        grep -A 10 "^tun:" "$CONFIG" 2>/dev/null | grep -qE 'enable:\s*true' && tun_enable="是"
        grep -A 10 "^tun:" "$CONFIG" 2>/dev/null | grep -qE 'enable:\s*false' && tun_enable="否"
        local tun_dev tun_gw tun_mtu
        tun_dev=$(grep -A 10 "^tun:" "$CONFIG" 2>/dev/null | grep -oE 'device[^:]*:.*' | head -1 | sed 's/.*: *//; s/[" ]//g')
        tun_gw=$(grep -A 10 "^tun:" "$CONFIG" 2>/dev/null | grep -oE 'gateway:.*' | head -1 | sed 's/gateway: *//; s/[" ]//g')
        tun_mtu=$(grep -A 10 "^tun:" "$CONFIG" 2>/dev/null | grep -oE 'mtu:.*' | head -1 | sed 's/mtu: *//; s/[" ]//g')
        printf "\n"
        line
        pl "${C}  TUN 配置${N}"
        line
        pl "  ${W}1${N}. 启用TUN:           ${G}${tun_enable}${N}"
        pl "  ${W}2${N}. 设备名:            ${G}${tun_dev:-默认(utun1989)}${N}"
        pl "  ${W}3${N}. 网关CIDR:          ${G}${tun_gw:-默认(198.18.0.1/24)}${N}"
        pl "  ${W}4${N}. MTU:               ${G}${tun_mtu:-默认(1500)}${N}"
        pl "  ${W}5${N}. DNS劫持开关"
        pl "  ${W}6${N}. 查看完整TUN配置"
        pl "  ${W}0${N}. 返回"
        printf "\n  请选择: "
        read choice
        case "$choice" in
            1)
                local newv
                if [ "$tun_enable" = "是" ]; then newv="false"; else newv="true"; fi
                pl "${Y}  即将修改 tun.enable=${newv}, 这会热重载配置, 确认? (y/N)${N}"
                printf "  > "; read confirm
                case "$confirm" in
                    y|Y) _patch_yaml_block "tun" "enable" "$newv" ;;
                    *) pl "  已取消" ;;
                esac
                ;;
            2)
                printf "  设备名 (回车=utun1989): "; read newv
                [ -z "$newv" ] && newv="utun1989"
                _patch_yaml_block "tun" "device" "$newv"
                ;;
            3)
                printf "  网关CIDR (回车=198.18.0.1/24): "; read newv
                [ -z "$newv" ] && newv="198.18.0.1/24"
                _patch_yaml_block "tun" "gateway" "$newv"
                ;;
            4)
                printf "  MTU (回车=1500): "; read newv
                case "$newv" in
                    ''|*[!0-9]*) newv="1500" ;;
                esac
                _patch_yaml_block "tun" "mtu" "$newv"
                ;;
            5)
                printf "  DNS劫持 (true/false): "; read newv
                case "$newv" in
                    true|false) _patch_yaml_block "tun" "dns-hijack" "$newv" ;;
                    *) pl "${R}  无效值${N}" ;;
                esac
                ;;
            6)
                pl "${C}  当前TUN配置:${N}"
                grep -A 12 "^tun:" "$CONFIG" 2>/dev/null || pl "${Y}  未找到tun段${N}"
                pause_for_input
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# DNS配置子菜单 (config.yaml 的 dns: 段)
# 用法: cc dns
# 功能: 交互式管理clash-rs内置DNS配置, 修改后自动备份+热重载+失败回滚
#   - enable:        DNS开关 (true/false)
#   - ipv6:          IPv6解析开关 (true解析AAAA / false仅A)
#   - enhanced-mode: fake-ip(假IP加速) / redir-host(真实IP)
#   - listen UDP/TCP: DNS监听地址 (默认0.0.0.0:1053, UDP和TCP分开改)
# 用途: 切换fake-ip模式 / 改DNS监听端口 / 关闭IPv6解析
# 注意: clash-rs的dns.listen是对象格式 {udp:addr, tcp:addr}, 不是字符串
#       修改时需同时改udp和tcp两个子字段, 否则会破坏DNS监听
do_dns_conf() {
    while true; do
        local dns_enable="未设置"
        grep -A 5 "^dns:" "$CONFIG" 2>/dev/null | grep -qE 'enable:\s*true' && dns_enable="是"
        grep -A 5 "^dns:" "$CONFIG" 2>/dev/null | grep -qE 'enable:\s*false' && dns_enable="否"
        local dns_ipv6 dns_mode dns_listen_udp dns_listen_tcp
        dns_ipv6=$(grep -A 15 "^dns:" "$CONFIG" 2>/dev/null | grep -oE 'ipv6:.*' | head -1 | sed 's/ipv6: *//; s/\r//g')
        dns_mode=$(grep -A 15 "^dns:" "$CONFIG" 2>/dev/null | grep -oE 'enhanced-mode:.*' | head -1 | sed 's/enhanced-mode: *//; s/[" ]//g; s/\r//g')
        # dns.listen 是对象: { udp: 0.0.0.0:1053, tcp: 0.0.0.0:1053 }
        dns_listen_udp=$(awk '/^dns:/{f=1} f&&/^[a-z]/&&!/^dns:/{exit} f&&/udp:/{print $2; exit}' "$CONFIG" 2>/dev/null)
        dns_listen_tcp=$(awk '/^dns:/{f=1} f&&/^[a-z]/&&!/^dns:/{exit} f&&/tcp:/{print $2; exit}' "$CONFIG" 2>/dev/null)
        printf "\n"
        line
        pl "${C}  DNS 配置 (clash-rs 内置DNS服务器)${N}"
        line
        pl "  ${W}1${N}. 启用DNS:          ${G}${dns_enable}${N}  (开: clash自解析 / 关: 用系统DNS)"
        pl "  ${W}2${N}. IPv6 (AAAA):     ${G}${dns_ipv6:-未设置}${N}  (是否解析IPv6地址)"
        pl "  ${W}3${N}. enhanced-mode:   ${G}${dns_mode:-未设置}${N}  (normal直连/fake-ip假IP/redir-host重定向)"
        pl "  ${W}4${N}. UDP监听:         ${G}${dns_listen_udp:-未设置}${N}  (DNS UDP监听地址)"
        pl "  ${W}5${N}. TCP监听:         ${G}${dns_listen_tcp:-未设置}${N}  (DNS TCP监听地址)"
        pl "  ${W}6${N}. 查看主DNS (nameserver)"
        pl "  ${W}7${N}. 查看兜底DNS (fallback)"
        pl "  ${W}8${N}. 查看完整DNS配置"
        pl "  ${W}9${N}. DNS解析测试 (cc dns-query)"
        pl "  ${W}0${N}. 返回"
        printf "\n  请选择: "
        read choice
        case "$choice" in
            1)
                local newv
                if [ "$dns_enable" = "是" ]; then newv="false"; else newv="true"; fi
                pl "${Y}  dns.enable 控制clash-rs内置DNS服务器是否工作:${N}"
                pl "  开(true): clash自己处理DNS, 支持fake-ip/分流/防泄漏 (推荐)"
                pl "  关(false): 使用系统DNS(/tmp/resolv.conf), 不做分流"
                _patch_yaml_block "dns" "enable" "$newv"
                ;;
            2)
                printf "  ipv6 (true/false): "; read newv
                case "$newv" in
                    true|false) _patch_yaml_block "dns" "ipv6" "$newv" ;;
                    *) pl "${R}  无效值${N}" ;;
                esac
                ;;
            3)
                pl "  ${Y}normal: 直连解析(不缓存) / fake-ip: 假IP(推荐,防DNS泄漏) / redir-host: 重定向${N}"
                printf "  enhanced-mode: "; read newv
                case "$newv" in
                    normal|fake-ip|redir-host) _patch_yaml_block "dns" "enhanced-mode" "$newv" ;;
                    *) pl "${R}  无效值${N}" ;;
                esac
                ;;
            4)
                pl "  ${Y}DNS UDP监听地址, 路由器透明代理通常用 0.0.0.0:1053${N}"
                printf "  UDP地址 (回车=0.0.0.0:1053): "; read newv
                [ -z "$newv" ] && newv="0.0.0.0:1053"
                _patch_yaml_block "dns" "udp" "$newv"
                ;;
            5)
                pl "  ${Y}DNS TCP监听地址, 用于TCP DNS查询, 通常与UDP相同${N}"
                printf "  TCP地址 (回车=0.0.0.0:1053): "; read newv
                [ -z "$newv" ] && newv="0.0.0.0:1053"
                _patch_yaml_block "dns" "tcp" "$newv"
                ;;
            6)
                pl "${C}  主DNS (nameserver):${N}"
                pl "  ${Y}用于常规域名解析, 支持udp/tcp/tls/https协议${N}"
                grep -A 30 "^dns:" "$CONFIG" 2>/dev/null | sed -n '/nameserver:/,/^[^ ]/p' | head -10
                pause_for_input
                ;;
            7)
                pl "${C}  兜底DNS (fallback):${N}"
                pl "  ${Y}主DNS解析失败时使用, 通常配境外DoT/DoH${N}"
                grep -A 50 "^dns:" "$CONFIG" 2>/dev/null | sed -n '/fallback:/,/^[^ ]/p' | head -10
                pause_for_input
                ;;
            8)
                pl "${C}  完整DNS配置:${N}"
                awk '/^dns:/{flag=1} flag&&/^[a-z]/&&!/^dns:/{exit} flag' "$CONFIG" 2>/dev/null
                pause_for_input
                ;;
            9)
                printf "  域名: "; read dn
                printf "  类型 (A/AAAA/CNAME/MX, 默认A): "; read dt
                [ -z "$dt" ] && dt="A"
                do_dns_query "$dn" "$dt"
                pause_for_input
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# Profile持久化子菜单 (config.yaml 的 profile: 段)
# 用法: cc profile
# 功能: 控制clash-rs重启后是否保留运行时状态, 修改后热重载
#   - store-selected:     持久化Selector组手动选择的节点 (默认true)
#   - store-fake-ip:      持久化fake-ip域名映射 (默认false, 开启可加速重启后首屏)
#   - store-smart-stats:  持久化smart组的统计/健康数据 (默认true)
# 用途: 重启后自动恢复之前选的节点 / 避免每次重启都要重新选节点
do_profile() {
    while true; do
        local ps_sel ps_fip ps_smart
        ps_sel=$(grep -A 5 "^profile:" "$CONFIG" 2>/dev/null | grep -oE 'store-selected:.*' | head -1 | sed 's/store-selected: *//')
        ps_fip=$(grep -A 5 "^profile:" "$CONFIG" 2>/dev/null | grep -oE 'store-fake-ip:.*' | head -1 | sed 's/store-fake-ip: *//')
        ps_smart=$(grep -A 5 "^profile:" "$CONFIG" 2>/dev/null | grep -oE 'store-smart-stats:.*' | head -1 | sed 's/store-smart-stats: *//')
        printf "\n"
        line
        pl "${C}  Profile 持久化配置${N}"
        line
        pl "  ${W}1${N}. store-selected:    ${G}${ps_sel:-默认true}${N}  (持久化Selector选择)"
        pl "  ${W}2${N}. store-fake-ip:    ${G}${ps_fip:-默认false}${N}  (持久化fake-ip映射)"
        pl "  ${W}3${N}. store-smart-stats:${G}${ps_smart:-默认true}${N}  (持久化smart组统计)"
        pl "  ${W}0${N}. 返回"
        printf "\n  请选择: "
        read choice
        case "$choice" in
            1)
                local newv
                [ "$ps_sel" = "true" ] && newv="false" || newv="true"
                _patch_yaml_block "profile" "store-selected" "$newv"
                ;;
            2)
                local newv
                [ "$ps_fip" = "true" ] && newv="false" || newv="true"
                _patch_yaml_block "profile" "store-fake-ip" "$newv"
                ;;
            3)
                local newv
                [ "$ps_smart" = "true" ] && newv="false" || newv="true"
                _patch_yaml_block "profile" "store-smart-stats" "$newv"
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# 通用: 修改yaml顶层字段 (如 external-controller/secret/mmdb 等)
# 与 _patch_yaml_block 不同, 这里改的是顶层 "field: value" 而不是 block 下子字段
# 自动备份 + 修改 + 热重载 + 失败回滚
_patch_toplevel() {
    local field="$1" value="$2"
    if [ ! -f "$CONFIG" ]; then
        pl "${R}  配置文件不存在${N}"
        return 1
    fi
    local bak="$CONFIG.cc.bak.$(date +%s)"
    cp "$CONFIG" "$bak" 2>/dev/null
    pl "  已备份: $bak"
    # 数值不加引号, 字符串加引号 (避免URL/特殊字符解析问题)
    local newval
    case "$value" in
        ''|*[!0-9]*)
            newval="${field}: \"${value}\""
            ;;
        *)
            newval="${field}: ${value}"
            ;;
    esac
    local tmp="${CONFIG}.tmp.$$"
    awk -v fld="$field" -v rep="$newval" '
        BEGIN { done=0; skipping=0 }
        $0 ~ "^" fld ":" { print rep; done=1; skipping=1; next }
        skipping && /^[ \t]+/ { next }
        { skipping=0; print }
        END { if (done == 0) print rep }
    ' "$CONFIG" > "$tmp" 2>/dev/null
    if [ ! -s "$tmp" ]; then
        pl "${R}  编辑配置失败${N}"
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$CONFIG"
    pl "  热重载配置..."
    if _reload_config; then
        sleep 1
        if is_running; then
            pl "${G}  ${field} 已修改为 ${value}${N}"
        else
            pl "${R}  重载后服务异常, 回滚...${N}"
            cp "$bak" "$CONFIG"
            _reload_config
            sleep 1
            pl "${R}  已回滚${N}"
            return 1
        fi
    else
        pl "${R}  配置重载失败, 回滚...${N}"
        cp "$bak" "$CONFIG"
        _reload_config
        pl "${Y}  已回滚, 服务未受影响${N}"
        return 1
    fi
}

# AUTO组配置子菜单 (proxy-groups 中 url-test 组参数)
# 用法: cc autogroup
# 功能: 交互式管理AUTO组的tolerance/interval/url-test-url
#   - tolerance:  切换容差(ms), 当前节点延迟 > 最低延迟+tolerance 才切换
#                 自适应模式: 连续12轮无切换且平均差>20ms时自动降到20ms
#                 切换后恢复到设定值
#   - interval:   自动测速间隔(秒), 每隔此时间自动测速并选择最快节点
#   - url:        测速URL, 默认 http://www.gstatic.com/generate_204
#   - 强制切换:    手动测速后(面板/cc test auto)强制切换到最低延迟节点(忽略tolerance)
#   - 流量保护:    代理流量>250KB/s时跳过自动切换, 避免打断下载/视频
# 注意: 修改后需重启clash-rs生效 (proxy-groups参数不支持热重载)
do_autogroup() {
    while true; do
        # 读取当前AUTO组配置
        local ag_tol ag_int ag_url ag_now ag_nodes ag_alive
        # 从config.yaml的proxy-groups段中找AUTO组的参数
        # AUTO组配置格式:
        #   - name: AUTO
        #     type: url-test
        #     url: http://www.gstatic.com/generate_204
        #     interval: 300
        #     tolerance: 30
        ag_tol=$(sed -n '/- name: AUTO/,/^- name:/p' "$CONFIG" 2>/dev/null | grep -oE 'tolerance:[[:space:]]*[0-9]+' | head -1 | sed 's/.*:[[:space:]]*//')
        ag_int=$(sed -n '/- name: AUTO/,/^- name:/p' "$CONFIG" 2>/dev/null | grep -oE 'interval:[[:space:]]*[0-9]+' | head -1 | sed 's/.*:[[:space:]]*//')
        ag_url=$(sed -n '/- name: AUTO/,/^- name:/p' "$CONFIG" 2>/dev/null | grep -oE 'url:[[:space:]]*.*' | head -1 | sed 's/url:[[:space:]]*//; s/[\" ]//g')

        # 从API获取实时状态
        if is_running; then
            local ag_resp
            ag_resp=$(api "/proxies/AUTO" 2>/dev/null)
            ag_now=$(echo "$ag_resp" | grep -oE '"now":"[^"]*"' | head -1 | sed 's/"now":"//; s/"//')
            ag_alive=$(echo "$ag_resp" | grep -oE '"alive":(true|false)' | head -1 | sed 's/"alive"://')
            ag_nodes=$(echo "$ag_resp" | grep -oE '"all":\[[^]]*\]' | head -1 | grep -oE '"[^"]*"' | wc -l)
        fi

        printf "\n"
        line
        pl "${C}  AUTO组配置 (url-test自动选择)${N}"
        line
        pl "  ${W}1${N}. tolerance(切换容差):  ${G}${ag_tol:-0}ms${N}"
        pl "      ${Y}当前节点延迟 > 最低延迟+此值 才切换, 防止频繁切换${N}"
        pl "      ${Y}自适应: 12轮不切且差>20ms时自动降到20ms, 切换后恢复设定值${N}"
        pl "  ${W}2${N}. interval(测速间隔):  ${G}${ag_int:-300}秒${N}"
        pl "      ${Y}每隔此时间自动测速所有节点并选择最快${N}"
        pl "  ${W}3${N}. url(测速地址):       ${G}${ag_url:-默认}${N}"
        pl "      ${Y}延迟测试用的URL, 需返回204, 建议用gstatic或cp.cloudflare${N}"
        pl "  ${W}4${N}. 强制切换到最快节点"
        pl "      ${Y}立即触发测速并强制切换到最低延迟节点(忽略tolerance)${N}"
        pl "  ${W}5${N}. 查看所有节点延迟"
        pl "  ${W}0${N}. 返回"
        printf "\n  请选择: "
        read choice
        case "$choice" in
            1)
                pl "${Y}  tolerance: 当前节点延迟与最低延迟的差值超过此值才切换${N}"
                pl "  ${Y}设为0=每次都切到最快(可能频繁断连), 50=差距大才切(稳定)${N}"
                pl "  ${Y}自适应逻辑: 连续12轮(约1小时)无切换且平均差>20ms时自动降到20ms${N}"
                pl "  ${Y}切换后自动恢复到设定值${N}"
                printf "  新值(0-500ms, 回车=取消): "; read newv
                [ -z "$newv" ] && continue
                if ! echo "$newv" | grep -qE '^[0-9]+$'; then
                    pl "${R}  请输入数字${N}"; sleep 1; continue
                fi
                if [ "$newv" -lt 0 ] || [ "$newv" -gt 500 ]; then
                    pl "${R}  范围: 0-500ms${N}"; sleep 1; continue
                fi
                pl "${Y}  即将修改 tolerance=$newv, 需重启clash-rs生效, 确认? (y/N)${N}"
                printf "  > "; read confirm
                case "$confirm" in
                    y|Y)
                        _patch_autogroup "tolerance" "$newv"
                        ;;
                    *) pl "  已取消" ;;
                esac
                ;;
            2)
                pl "${Y}  interval: 每隔此秒数自动测速一次${N}"
                pl "  ${Y}值越小越快发现快节点, 但消耗更多带宽和CPU${N}"
                pl "  ${Y}建议: 300(5分钟)=平衡, 60=激进, 600=保守${N}"
                printf "  新值(60-3600秒, 回车=取消): "; read newv
                [ -z "$newv" ] && continue
                if ! echo "$newv" | grep -qE '^[0-9]+$'; then
                    pl "${R}  请输入数字${N}"; sleep 1; continue
                fi
                if [ "$newv" -lt 60 ] || [ "$newv" -gt 3600 ]; then
                    pl "${R}  范围: 60-3600秒${N}"; sleep 1; continue
                fi
                pl "${Y}  即将修改 interval=$newv, 需重启clash-rs生效, 确认? (y/N)${N}"
                printf "  > "; read confirm
                case "$confirm" in
                    y|Y)
                        _patch_autogroup "interval" "$newv"
                        ;;
                    *) pl "  已取消" ;;
                esac
                ;;
            3)
                pl "${Y}  url: 测速用的URL, 需返回HTTP 204${N}"
                pl "  ${Y}推荐:${N}"
                pl "    http://www.gstatic.com/generate_204 (Google, 默认)"
                pl "    https://cp.cloudflare.com/generate_204 (Cloudflare)"
                pl "    http://www.google.com/generate_204"
                printf "  新URL (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                pl "${Y}  即将修改 url=$newv, 需重启clash-rs生效, 确认? (y/N)${N}"
                printf "  > "; read confirm
                case "$confirm" in
                    y|Y)
                        _patch_autogroup "url" "$newv"
                        ;;
                    *) pl "  已取消" ;;
                esac
                ;;
            4)
                pl "${Y}  强制切换: 触发测速并强制选择最低延迟节点${N}"
                pl "  ${Y}此操作会忽略tolerance和流量保护, 立即切换到最快节点${N}"
                pl "  ${Y}注意: 如果当前正在下载/看视频, 切换会导致连接重置${N}"
                printf "  确认强制切换? (y/N) "; read confirm
                case "$confirm" in
                    y|Y)
                        if ! is_running; then
                            pl "${R}  clash-rs未运行${N}"; sleep 1; continue
                        fi
                        pl "${C}  正在测速...${N}"
                        # 调用API测速 (会触发force_fastest标志)
                        local test_result
                        test_result=$(curl -s -H "Authorization: Bearer $SECRET" \
                            "http://${API_HOST}:${API_PORT}/proxies/AUTO/delay?url=$(urlencode "${ag_url:-http://www.gstatic.com/generate_204}")&timeout=5000" 2>/dev/null)
                        pl "  测速结果: ${G}${test_result}${N}"
                        # 触发实际流量让force_fastest生效
                        curl -s -o /dev/null --connect-timeout 5 http://www.gstatic.com/generate_204 2>/dev/null
                        sleep 1
                        # 查看切换后的节点
                        local new_now
                        new_now=$(api "/proxies/AUTO" 2>/dev/null | grep -oE '"now":"[^"]*"' | head -1 | sed 's/"now":"//; s/"//')
                        pl "  当前节点: ${G}${new_now:-未知}${N}"
                        pause_for_input
                        ;;
                    *) pl "  已取消" ;;
                esac
                ;;
            5)
                pl "${C}  AUTO组所有节点延迟${N}"
                line
                if ! is_running; then
                    pl "${R}  clash-rs未运行${N}"; pause_for_input; continue
                fi
                local all_resp delays
                all_resp=$(api "/proxies" 2>/dev/null)
                if [ -z "$all_resp" ]; then
                    pl "${R}  API无响应${N}"; pause_for_input; continue
                fi
                # 获取AUTO组所有节点名
                local auto_nodes
                auto_nodes=$(api "/proxies/AUTO" 2>/dev/null | grep -oE '"all":\[([^]]*)\]' | head -1 | sed 's/"all":\[//; s/\]//' | tr ',' '\n' | sed 's/"//g')
                if [ -z "$auto_nodes" ]; then
                    pl "${R}  未获取到节点列表${N}"; pause_for_input; continue
                fi
                # 遍历节点显示延迟
                printf "%-20s %s\n" "节点" "延迟"
                echo "-------------------- -------"
                echo "$auto_nodes" | while read n; do
                    [ -z "$n" ] && continue
                    local d
                    d=$(echo "$all_resp" | tr ',' '\n' | grep -F "\"$n\"" | grep -oE '"delay":[0-9]+' | head -1 | sed 's/"delay"://')
                    if [ "$n" = "$ag_now" ]; then
                        printf "%-20s %s\n" "$n" "${G}${d:-N/A}ms (当前)${N}"
                    else
                        printf "%-20s %s\n" "$n" "${d:-N/A}ms"
                    fi
                done
                pause_for_input
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# 修改AUTO组参数 (sed操作config.yaml + 重启)
# $1=字段名(tolerance/interval/url) $2=新值
_patch_autogroup() {
    local field="$1" value="$2"
    # 备份
    cp "$CONFIG" "$CONFIG.bak"
    # 在AUTO组范围内替换字段
    # sed: 在 "- name: AUTO" 到下一个 "- name:" 之间替换
    if [ "$field" = "url" ]; then
        # URL可能包含特殊字符, 用不同方式
        sed -i "/- name: AUTO/,/^- name:/{s|url:.*|url: ${value}|}" "$CONFIG"
    else
        sed -i "/- name: AUTO/,/^- name:/{s/${field}:.*/${field}: ${value}/}" "$CONFIG"
    fi
    # 验证修改
    local verify
    verify=$(sed -n '/- name: AUTO/,/^- name:/p' "$CONFIG" | grep -oE "${field}:[[:space:]]*[^[:space:]]+" | head -1)
    pl "  修改后: ${G}${verify:-未找到}${N}"
    # 重启生效
    pl "${Y}  重启clash-rs使配置生效...${N}"
    /etc/init.d/clash-rs restart 2>&1 | head -5
    sleep 3
    if is_running; then
        pl "${G}  重启成功, 配置已生效${N}"
    else
        pl "${R}  重启失败, 恢复备份${N}"
        cp "$CONFIG.bak" "$CONFIG"
        /etc/init.d/clash-rs restart 2>&1 | head -3
    fi
}

# clash-rs 核心配置子菜单 (顶层字段热修改)
# 覆盖 external-controller / secret / external-ui / external-ui-url /
#      cors-allow-origins / mmdb / geosite / geosite-download-url /
#      routing-mark / interface / keep-alive-interval
# 这些都是 config.yaml 顶层字段 (clash-rs 0.10.8 实测支持, 勿加mihomo专属字段)
do_clash_conf() {
    while true; do
        # 读取当前各字段值
        local ec_ctrl ec_secret ec_ui ec_uiurl ec_cors ec_mmdb ec_geosite ec_geodl ec_rmark ec_if ec_kalive
        ec_ctrl=$(grep -E "^external-controller:" "$CONFIG" 2>/dev/null | sed 's/^external-controller: *//; s/\r//g; s/^"//; s/"$//')
        ec_secret=$(grep -E "^secret:" "$CONFIG" 2>/dev/null | sed 's/^secret: *//; s/\r//g; s/^"//; s/"$//')
        ec_ui=$(grep -E "^external-ui:" "$CONFIG" 2>/dev/null | sed 's/^external-ui: *//; s/\r//g; s/^"//; s/"$//')
        ec_uiurl=$(grep -E "^external-ui-url:" "$CONFIG" 2>/dev/null | sed 's/^external-ui-url: *//; s/\r//g; s/^"//; s/"$//')
        ec_cors=$(grep -E "^cors-allow-origins:" "$CONFIG" 2>/dev/null | sed 's/^cors-allow-origins: *//; s/\r//g')
        ec_mmdb=$(grep -E "^mmdb:" "$CONFIG" 2>/dev/null | sed 's/^mmdb: *//; s/\r//g; s/^"//; s/"$//')
        ec_geosite=$(grep -E "^geosite:" "$CONFIG" 2>/dev/null | sed 's/^geosite: *//; s/\r//g; s/^"//; s/"$//')
        ec_geodl=$(grep -E "^geosite-download-url:" "$CONFIG" 2>/dev/null | sed 's/^geosite-download-url: *//; s/\r//g; s/^"//; s/"$//')
        ec_rmark=$(grep -E "^routing-mark:" "$CONFIG" 2>/dev/null | sed 's/^routing-mark: *//; s/\r//g')
        ec_if=$(grep -E "^interface:" "$CONFIG" 2>/dev/null | sed 's/^interface: *//; s/\r//g; s/^"//; s/"$//')
        ec_kalive=$(grep -E "^keep-alive-interval:" "$CONFIG" 2>/dev/null | sed 's/^keep-alive-interval: *//; s/\r//g')
        printf "\n"
        line
        pl "${C}  clash-rs 核心配置 (顶层字段)${N}"
        line
        pl "  ${W}1${N}. external-controller:  ${G}${ec_ctrl:-默认(0.0.0.0:9090)}${N}"
        pl "      ${Y}RESTful API监听地址, 控制面板/脚本通过此地址管理clash-rs${N}"
        pl "  ${W}2${N}. secret:               ${G}$([ -n "$ec_secret" ] && echo '已设置' || echo '默认(空)')${N}"
        pl "      ${Y}API访问密钥, 防止未授权访问, 建议至少16位随机字符串${N}"
        pl "  ${W}3${N}. external-ui:          ${G}${ec_ui:-默认(无)}${N}"
        pl "      ${Y}Web面板静态文件目录路径, 如 /etc/clash/ui${N}"
        pl "  ${W}4${N}. external-ui-url:      ${G}${ec_uiurl:-默认(无)}${N}"
        pl "      ${Y}面板自动下载地址, 启动时若ui目录为空会从此URL下载${N}"
        pl "  ${W}5${N}. cors-allow-origins:   ${G}${ec_cors:-默认(无)}${N}"
        pl "      ${Y}跨域来源白名单, 在线面板(如d.metacubex.one)调用API时需要${N}"
        pl "  ${W}6${N}. mmdb:                 ${G}${ec_mmdb:-默认(./Country.mmdb)}${N}"
        pl "      ${Y}MaxMind GeoIP数据库路径, 用于GEOIP规则判定国家${N}"
        pl "  ${W}7${N}. geosite:              ${G}${ec_geosite:-默认(无)}${N}"
        pl "      ${Y}GeoSite数据库路径, 用于GEOSITE规则匹配域名集合${N}"
        pl "  ${W}8${N}. geosite-download-url: ${G}${ec_geodl:-默认(无)}${N}"
        pl "      ${Y}GeoSite数据库下载地址, 缺失时自动下载${N}"
        pl "  ${W}9${N}. routing-mark:         ${G}${ec_rmark:-默认(无)}${N}"
        pl "      ${Y}出站连接SO_MARK标记, 用于策略路由分流${N}"
        pl "  ${W}10${N}. interface:           ${G}${ec_if:-默认(无)}${N}"
        pl "      ${Y}出站绑定网卡名(注意是interface不是interface-name)${N}"
        pl "  ${W}11${N}. keep-alive-interval: ${G}${ec_kalive:-默认(30)}${N}"
        pl "      ${Y}TCP keep-alive探测间隔秒数, 防止NAT断连${N}"
        pl "  ${W}0${N}. 返回"
        printf "\n  请选择: "
        read choice
        case "$choice" in
            1)
                pl "${Y}  API监听地址, 格式 IP:PORT, 0.0.0.0:9090=所有网卡${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "external-controller" "$newv"
                sleep 1
                ;;
            2)
                pl "${Y}  API密钥, 建议使用强随机字符串${N}"
                printf "  新值 (回车=取消, 输入clear清除): "; read newv
                [ -z "$newv" ] && continue
                [ "$newv" = "clear" ] && newv=""
                _patch_toplevel "secret" "$newv"
                sleep 1
                ;;
            3)
                pl "${Y}  Web面板目录, 如 /etc/clash/ui${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "external-ui" "$newv"
                sleep 1
                ;;
            4)
                pl "${Y}  面板下载地址URL, 留空则不自动下载${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "external-ui-url" "$newv"
                sleep 1
                ;;
            5)
                pl "${Y}  跨域白名单, 多个用逗号分隔, 如 https://d.metacubex.one${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "cors-allow-origins" "$newv"
                sleep 1
                ;;
            6)
                pl "${Y}  GeoIP数据库路径, 如 /etc/clash/Country.mmdb${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "mmdb" "$newv"
                sleep 1
                ;;
            7)
                pl "${Y}  GeoSite数据库路径, 如 /etc/clash/geosite.dat${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "geosite" "$newv"
                sleep 1
                ;;
            8)
                pl "${Y}  GeoSite下载URL${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "geosite-download-url" "$newv"
                sleep 1
                ;;
            9)
                pl "${Y}  SO_MARK数值标记 (0~4294967295)${N}"
                printf "  新值 (回车=取消): "; read newv
                case "$newv" in
                    ''|*[!0-9]*) pl "${R}  无效数字${N}"; sleep 1; continue ;;
                esac
                _patch_toplevel "routing-mark" "$newv"
                sleep 1
                ;;
            10)
                pl "${Y}  出站绑定网卡名, 如 pppoe-wan 或 eth0${N}"
                printf "  新值 (回车=取消): "; read newv
                [ -z "$newv" ] && continue
                _patch_toplevel "interface" "$newv"
                sleep 1
                ;;
            11)
                pl "${Y}  keep-alive间隔秒数 (推荐15~60)${N}"
                printf "  新值 (回车=取消): "; read newv
                case "$newv" in
                    ''|*[!0-9]*) pl "${R}  无效数字${N}"; sleep 1; continue ;;
                esac
                _patch_toplevel "keep-alive-interval" "$newv"
                sleep 1
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# 通用: 修改yaml顶层块下的字段 (block: tun/dns/profile, field: enable/ipv6/mtu等)
# 自动备份 + 修改 + 热重载 + 失败回滚
_patch_yaml_block() {
    local block="$1" field="$2" value="$3"
    if [ ! -f "$CONFIG" ]; then
        pl "${R}  配置文件不存在${N}"
        return 1
    fi
    local bak="$CONFIG.cc.bak.$(date +%s)"
    cp "$CONFIG" "$bak" 2>/dev/null
    pl "  已备份: $bak"
    # 查找block段, 在block:行之后到下一个顶层字段之前的范围内修改字段
    # 若字段不存在则添加
    local tmp="${CONFIG}.tmp.$$"
    awk -v blk="$block" -v fld="$field" -v val="$value" '
        BEGIN { inblk=0; fld_done=0; indent="  " }
        /^[a-zA-Z]/ {
            if (inblk && fld_done == 0) {
                # 字段不存在, 在block段末尾追加
                print indent fld ": " val
                fld_done = 1
            }
            if ($0 ~ "^" blk ":") { inblk=1 } else { inblk=0 }
            fld_done = 0
            print
            next
        }
        inblk && $0 ~ "^[ ]+" fld ":" {
            sub(/[^:]+: .*/, fld ": " val)
            fld_done = 1
        }
        { print }
        END {
            if (inblk && fld_done == 0) {
                print indent fld ": " val
            }
        }
    ' "$CONFIG" > "$tmp" 2>/dev/null
    if [ ! -s "$tmp" ]; then
        pl "${R}  编辑配置失败${N}"
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$CONFIG"
    pl "  热重载配置..."
    if _reload_config; then
        sleep 1
        if is_running; then
            pl "${G}  ${block}.${field} 已修改为 ${value}${N}"
        else
            pl "${R}  重载后服务异常, 回滚...${N}"
            cp "$bak" "$CONFIG"
            _reload_config
            sleep 1
            pl "${R}  已回滚${N}"
            return 1
        fi
    else
        pl "${R}  配置重载失败, 回滚...${N}"
        cp "$bak" "$CONFIG"
        _reload_config
        pl "${Y}  已回滚, 服务未受影响${N}"
        return 1
    fi
}

# ============================================================
# 设置子菜单
# ============================================================

show_settings() {
    while true; do
        # 读取当前设置
        [ -f "$BOOT_DELAY_FILE" ] && BOOT_DELAY=$(cat $BOOT_DELAY_FILE 2>/dev/null) || BOOT_DELAY=0
        MEM_MB=$(get_mem_threshold_mb)
        AUTO_START="否"
        ls /etc/rc.d/S*clash-rs >/dev/null 2>&1 && AUTO_START="是"
        WATCHDOG_ON="关"
        [ -f "$WATCHDOG_PID" ] && kill -0 $(cat $WATCHDOG_PID 2>/dev/null) 2>/dev/null && WATCHDOG_ON="开"
        # 当前模式
        CUR_MODE=$(grep "^mode:" $CONFIG 2>/dev/null | awk '{print $2}')
        [ -z "$CUR_MODE" ] && CUR_MODE="rule"

        printf "\n"
        line
        pl "${C}  启动设置菜单${N}"
        line
        pl "  ${W}1${N}. 开机自启:     ${G}${AUTO_START}${N}"
        pl "  ${W}2${N}. 启动延迟:     ${G}${BOOT_DELAY}秒${N}  (解决开机网络未就绪)"
        pl "  ${W}3${N}. 内存限制:     ${G}${MEM_MB}MB${N}  (0=不限制, Soft=拒新连接, Hard=1.5x关旧连接)"
        pl "  ${W}4${N}. 内存看门狗:   ${G}${WATCHDOG_ON}${N}  (超限自动重启)"
        # 节点健康检查状态
        NODE_HEALTH_ON="关"
        NH_VAL=$(cat $NODE_HEALTH_FILE 2>/dev/null)
        [ "$NH_VAL" = "1" ] && NODE_HEALTH_ON="开"
        NH_INT=$(get_health_interval)
        NH_TO=$(get_health_timeout)
        pl "  ${W}5${N}. 节点健康检查: ${G}${NODE_HEALTH_ON}${N}  (间隔${NH_INT}s 超时${NH_TO}s)"
        pl "  ${W}6${N}. 运行模式:     ${G}${CUR_MODE}${N}  (rule/global/direct)"
        pl "  ${W}7${N}. 编辑配置文件"
        pl "  ${W}8${N}. 验证配置文件"
        pl "  ${W}9${N}. 查看iptables规则"
        pl "  ${W}10${N}. 查看ipset CN IP"
        pl "  ${W}11${N}. 更新GeoIP数据库"
        pl "  ${W}12${N}. 更新CN IP列表"
        pl "  ${W}13${N}. 网络参数优化  ${Y}(已持久化)${N}"
        pl "  ${W}14${N}. 健康检查参数  间隔=${G}${NH_INT}s${N} 超时=${G}${NH_TO}s${N}"
        pl "  ${W}15${N}. 配置备份与回滚"
        # 批次9: 配置字段傻瓜化 (读取当前值显示)
        CUR_PORT=$(grep -E "^port:" $CONFIG 2>/dev/null | awk '{print $2}')
        CUR_IPV6=$(grep -E "^ipv6:" $CONFIG 2>/dev/null | awk '{print $2}')
        CUR_LOGLVL=$(grep -E "^log-level:" $CONFIG 2>/dev/null | awk '{print $2}')
        CUR_ALLOWLAN=$(grep -E "^allow-lan:" $CONFIG 2>/dev/null | awk '{print $2}')
        CUR_ANYTLS_BUF=$(grep -A 5 "^experimental:" $CONFIG 2>/dev/null | grep -oE 'anytls-duplex-buffer-size:.*' | awk '{print $2}')
        CUR_TCP_BUF=$(grep -A 5 "^experimental:" $CONFIG 2>/dev/null | grep -oE 'tcp-buffer-size:.*' | awk '{print $2}')
        CUR_IGNORERESOLVE=$(grep -A 5 "^experimental:" $CONFIG 2>/dev/null | grep -oE 'ignore-resolve-fail:.*' | awk '{print $2}')
        pl "  ${W}16${N}. HTTP代理端口:   ${G}${CUR_PORT:-默认}${N}  (cc patch port)"
        pl "  ${W}17${N}. IPv6开关:       ${G}${CUR_IPV6:-默认}${N}  (顶层, 影响AAAA解析与出站)"
        pl "  ${W}18${N}. 日志级别:       ${G}${CUR_LOGLVL:-默认}${N}  (trace/debug/info/warning/error/silent)"
        pl "  ${W}19${N}. 允许局域网:     ${G}${CUR_ALLOWLAN:-默认}${N}  (allow-lan, 改后热生效)"
        pl "  ${W}20${N}. experimental:   ${G}anytls-buf=${CUR_ANYTLS_BUF:-默认} tcp-buf=${CUR_TCP_BUF:-默认} ign-resolve=${CUR_IGNORERESOLVE:-默认}${N}  (子菜单)"
        pl ""
        pl "  ${W}0${N}. 返回上级菜单"
        printf "\n  请选择: "
        read choice

        case $choice in
            1)
                if ls /etc/rc.d/S*clash-rs >/dev/null 2>&1; then
                    $INIT_SCRIPT disable 2>/dev/null
                    rm -f /etc/rc.d/S*clash-rs 2>/dev/null
                    pl "${Y}  已关闭开机自启${N}"
                else
                    $INIT_SCRIPT enable 2>/dev/null
                    pl "${G}  已开启开机自启${N}"
                fi
                sleep 1
                ;;
            2)
                pl "${Y}  推荐设置30~120秒, 0=不延迟${N}"
                printf "  请输入延迟秒数(0~300): "
                read sec
                case "$sec" in
                    [0-9]|[0-9][0-9]|[1-2][0-9][0-9]|300)
                        echo "$sec" > $BOOT_DELAY_FILE
                        pl "${G}  已设置启动延迟: ${sec}秒${N}"
                        ;;
                    *)
                        pl "${R}  输入有误${N}"
                        ;;
                esac
                sleep 1
                ;;
            3)
                pl "${Y}  当前限制: ${MEM_MB}MB${N}"
                pl "  内存保护机制:"
                pl "    Soft限制: 超过时拒绝新连接, 保持现有连接不断网"
                HARD_MB=$((MEM_MB * 3 / 2))
                pl "    Hard限制: ${HARD_MB}MB (1.5x), 智能关闭空闲/UDP连接"
                pl "  常用值: 32(可能OOM)/48(默认稳定)/64/0(不限制)"
                printf "  请输入内存限制(MB, 0=不限制): "
                read mb
                case "$mb" in
                    [0-9]*)
                        kb=$((mb * 1024))
                        echo "$kb" > $MEM_THRESHOLD_FILE
                        pl "${G}  已设置内存限制: ${mb}MB (${kb}KB)${N}"
                        pl "${Y}  需要重启生效: cc restart${N}"
                        ;;
                    *)
                        pl "${R}  输入有误${N}"
                        ;;
                esac
                sleep 1
                ;;
            4)
                if [ "$WATCHDOG_ON" = "开" ]; then
                    WPID=$(cat $WATCHDOG_PID 2>/dev/null)
                    [ -n "$WPID" ] && kill $WPID 2>/dev/null
                    rm -f $WATCHDOG_PID
                    pl "${Y}  已关闭看门狗${N}"
                else
                    # 启动看门狗 (从init脚本获取)
                    MEM_LIMIT=$(cat $MEM_THRESHOLD_FILE 2>/dev/null)
                    [ -z "$MEM_LIMIT" ] && MEM_LIMIT=0
                    if [ "$MEM_LIMIT" -gt 0 ] 2>/dev/null; then
                        $INIT_SCRIPT start_watchdog $MEM_LIMIT 2>/dev/null
                        if [ $? -ne 0 ] 2>/dev/null; then
                            # 手动启动简易看门狗
                            (
                                while true; do
                                    sleep 30
                                    PID=$(cat $PID_FILE 2>/dev/null)
                                    [ -z "$PID" ] || [ ! -d "/proc/$PID" ] && continue
                                    THRESHOLD=$(cat $MEM_THRESHOLD_FILE 2>/dev/null)
                                    [ -z "$THRESHOLD" ] && THRESHOLD=49152
                                    [ "$THRESHOLD" -eq 0 ] 2>/dev/null && continue
                                    VMRSS=$(grep VmRSS /proc/$PID/status 2>/dev/null | awk '{print $2}')
                                    [ -z "$VMRSS" ] && continue
                                    if [ "$VMRSS" -gt "$THRESHOLD" ]; then
                                        echo "$(date): VmRSS=$((VMRSS/1024))MB > threshold=$((THRESHOLD/1024))MB, restarting" >> $WATCHDOG_LOG
                                        $INIT_SCRIPT restart
                                        break
                                    fi
                                done
                            ) &
                            echo $! > $WATCHDOG_PID
                            pl "${G}  已开启看门狗 (PID:$(cat $WATCHDOG_PID))${N}"
                        else
                            pl "${G}  已开启看门狗${N}"
                        fi
                    else
                        pl "${Y}  内存限制为0(不限制), 看门狗无意义${N}"
                    fi
                fi
                sleep 1
                ;;
            5)
                # 节点健康检查开关
                NH_VAL=$(cat $NODE_HEALTH_FILE 2>/dev/null)
                if [ "$NH_VAL" = "1" ]; then
                    echo 0 > $NODE_HEALTH_FILE
                    pl "${Y}  已关闭节点健康检查${N}"
                    pl "  (AUTO为select类型, crontab定时跑cc autoswitch自动测速)"
                else
                    echo 1 > $NODE_HEALTH_FILE
                    NH_INT=$(get_health_interval)
                    NH_TO=$(get_health_timeout)
                    pl "${G}  已开启节点健康检查${N}"
                    pl "  每${NH_INT}秒检测当前AUTO节点, 超时${NH_TO}s, 挂了自动切换"
                    pl "  查看日志: cat $WATCHDOG_LOG"
                    pl "  ${Y}参数可调: cc settings 选项14${N}"
                fi
                sleep 1
                ;;
            6)
                pl "${C}  运行模式:${N}"
                pl "  ${G}1${N}. rule   - 规则分流 (默认, 国内直连国外代理)"
                pl "  ${G}2${N}. global - 全部代理 (所有流量走代理)"
                pl "  ${G}3${N}. direct - 全部直连 (关闭代理)"
                printf "  请选择: "
                read mode_choice
                case "$mode_choice" in
                    1) new_mode="rule" ;;
                    2) new_mode="global" ;;
                    3) new_mode="direct" ;;
                    *) pl "${R}  无效选择${N}"; continue ;;
                esac
                # 通过API切换模式
                result=$(curl -s -X PATCH -H "Authorization: Bearer $SECRET" -H "Content-Type: application/json" \
                    -d "{\"mode\":\"$new_mode\"}" "http://${API_HOST}:${API_PORT}/configs" 2>/dev/null)
                # 同时修改配置文件
                sed -i "s/^mode:.*/mode: $new_mode/" $CONFIG 2>/dev/null
                pl "${G}  已切换到: $new_mode 模式${N}"
                sleep 1
                ;;
            7)
                if which vi >/dev/null 2>&1; then
                    vi $CONFIG
                elif which nano >/dev/null 2>&1; then
                    nano $CONFIG
                else
                    pl "${R}  无可用编辑器, 尝试: cat $CONFIG${N}"
                    head -50 $CONFIG
                fi
                ;;
            8)
                pl "${C}  验证配置文件...${N}"
                $CLASH_BIN -f $CONFIG -t 2>&1
                ;;
            9)
                pl "${C}  iptables NAT规则:${N}"
                pl "--- clash_reroute (TCP透明代理) ---"
                iptables -t nat -L clash_reroute -n 2>/dev/null || pl "${Y}  无clash_reroute链${N}"
                echo ""
                pl "--- clash_dns (DNS劫持) ---"
                iptables -t nat -L clash_dns -n 2>/dev/null || pl "${Y}  无clash_dns链${N}"
                echo ""
                pl "--- clash_mark (防回环) ---"
                iptables -t mangle -L clash_mark -n 2>/dev/null || pl "${Y}  无clash_mark链${N}"
                ;;
            10)
                cnt=$(ipset list cn_ip -t 2>/dev/null | grep "Number of entries" | awk '{print $4}')
                pl "  CN IP条目数: ${cnt:-0}"
                if [ "$cnt" = "0" ] || [ -z "$cnt" ]; then
                    pl "${Y}  CN IP列表为空, 建议更新 (选项12)${N}"
                fi
                ;;
            11)
                pl "${C}  更新GeoIP数据库...${N}"
                if is_running; then
                    curl -sL -o /tmp/country.mmdb -x http://127.0.0.1:7890 https://github.com/Dreamacro/maxmind-geoip/releases/latest/download/Country.mmdb 2>/dev/null
                    # B7校验: 文件存在 + 大小 > 100KB + magic header (MaxMind数据库)
                    if [ -f /tmp/country.mmdb ]; then
                        local sz=$(wc -c < /tmp/country.mmdb 2>/dev/null)
                        local magic=$(head -c 4 /tmp/country.mmdb 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \n')
                        if [ "$sz" -lt 102400 ] 2>/dev/null; then
                            pl "${R}  下载文件过小 (${sz}B < 100KB), 疑似错误页${N}"
                            head -c 200 /tmp/country.mmdb 2>/dev/null
                            echo ""
                            pl "${Y}  已放弃更新, 保留旧版本${N}"
                            rm -f /tmp/country.mmdb
                        elif [ -z "$magic" ] || ! echo "$magic" | grep -qiE '^[0-9a-f]{8}$'; then
                            pl "${R}  文件头异常 (magic: ${magic:-空}), 疑似非二进制${N}"
                            rm -f /tmp/country.mmdb
                        else
                            # 备份旧版本
                            [ -f "$CLASH_DIR/country.mmdb" ] && cp "$CLASH_DIR/country.mmdb" "$BACKUP_DIR/country.mmdb.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
                            mkdir -p "$BACKUP_DIR" 2>/dev/null
                            mv /tmp/country.mmdb $CLASH_DIR/country.mmdb
                            pl "${G}  GeoIP数据库已更新${N}"
                            pl "  大小: $((sz/1024)) KB  magic: 0x${magic}"
                            pl "${Y}  需要重启生效: cc restart${N}"
                        fi
                    else
                        pl "${R}  下载失败 (curl返回非0)${N}"
                        pl "${Y}  请检查代理是否可用, 或稍后重试${N}"
                    fi
                else
                    pl "${R}  需要先启动clash-rs才能下载${N}"
                fi
                ;;
            12)
                pl "${C}  更新CN IP列表...${N}"
                if is_running; then
                    curl -sL -o /tmp/cn_ip.txt -x http://127.0.0.1:7890 https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt 2>/dev/null
                    # B7校验: 文件存在 + 行数 > 1000 + 每行符合CIDR格式
                    if [ -f /tmp/cn_ip.txt ]; then
                        local sz=$(wc -c < /tmp/cn_ip.txt 2>/dev/null)
                        local lines=$(wc -l < /tmp/cn_ip.txt 2>/dev/null)
                        # 抽样验证前5行是否CIDR格式 (1.2.3.0/24 或 ::/64)
                        local bad=$(head -10 /tmp/cn_ip.txt | grep -vE '^[0-9a-fA-F:.]+/[0-9]+$' | grep -vE '^#|^$' | head -1)
                        if [ "$lines" -lt 1000 ] 2>/dev/null; then
                            pl "${R}  下载文件行数过少 (${lines}行 < 1000), 疑似错误页${N}"
                            head -5 /tmp/cn_ip.txt
                            pl "${Y}  已放弃更新, 保留旧版本${N}"
                            rm -f /tmp/cn_ip.txt
                        elif [ -n "$bad" ]; then
                            pl "${R}  文件格式异常 (非CIDR行: $bad)${N}"
                            pl "${Y}  已放弃更新, 保留旧版本${N}"
                            rm -f /tmp/cn_ip.txt
                        else
                            # 备份旧版本
                            mkdir -p "$BACKUP_DIR" 2>/dev/null
                            [ -f "$CLASH_DIR/cn_ip.txt" ] && cp "$CLASH_DIR/cn_ip.txt" "$BACKUP_DIR/cn_ip.txt.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null
                            mv /tmp/cn_ip.txt $CLASH_DIR/cn_ip.txt
                            # 重新加载ipset
                            ipset flush cn_ip 2>/dev/null
                            awk '!/^$/&&!/^#/{printf("add cn_ip %s\n",$0)}' $CLASH_DIR/cn_ip.txt > /tmp/cn_ip.ipset
                            ipset -! restore < /tmp/cn_ip.ipset
                            rm -f /tmp/cn_ip.ipset
                            cnt=$(ipset list cn_ip -t 2>/dev/null | grep "Number of entries" | awk '{print $4}')
                            pl "${G}  CN IP已更新: ${cnt:-0}条 (文件 ${lines}行, $((sz/1024))KB)${N}"
                        fi
                    else
                        pl "${R}  下载失败 (curl返回非0)${N}"
                        pl "${Y}  请检查代理是否可用, 或稍后重试${N}"
                    fi
                else
                    pl "${R}  需要先启动clash-rs才能下载${N}"
                fi
                ;;
            13)
                pl "${C}  应用网络参数优化 v4 (持久化)...${N}"
                # ===== 1. 运行时立即生效 =====
                # TCP优化
                echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null
                echo 15 > /proc/sys/net/ipv4/tcp_fin_timeout 2>/dev/null
                echo 300 > /proc/sys/net/ipv4/tcp_keepalive_time 2>/dev/null
                echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl 2>/dev/null
                echo 3 > /proc/sys/net/ipv4/tcp_keepalive_probes 2>/dev/null
                echo 2048 > /proc/sys/net/ipv4/tcp_max_syn_backlog 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_syncookies 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_sack 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_mtu_probing 2>/dev/null
                echo 8192 > /proc/sys/net/ipv4/tcp_max_tw_buckets 2>/dev/null
                echo "1024 65535" > /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null
                # TCP低延迟+交互优化
                echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_thin_linear_timeouts 2>/dev/null
                echo 32768 > /proc/sys/net/ipv4/tcp_max_orphans 2>/dev/null
                echo 8 > /proc/sys/net/ipv4/tcp_retries2 2>/dev/null
                echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
                # CPU性能模式 (非sysctl, 走rc.local)
                for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo performance > $cpu 2>/dev/null
                done
                # RPS多核分发 (非sysctl, 走rc.local)
                for f in /sys/class/net/eth*/queues/rx-*/rps_cpus; do
                    echo 3 > $f 2>/dev/null
                done
                echo 32768 > /proc/sys/net/core/rps_sock_flow_entries 2>/dev/null
                # 软中断预算
                echo 600 > /proc/sys/net/core/netdev_budget 2>/dev/null
                echo 8000 > /proc/sys/net/core/netdev_budget_usecs 2>/dev/null
                # DNS优化 (直连DNS, 不用127.0.0.1避免回环)
                echo "nameserver 119.29.29.29" > /tmp/resolv.conf 2>/dev/null
                echo "nameserver 223.5.5.5" >> /tmp/resolv.conf 2>/dev/null
                uci del_list dhcp.@dnsmasq[0].server 2>/dev/null
                uci add_list dhcp.@dnsmasq[0].server='119.29.29.29' 2>/dev/null
                uci add_list dhcp.@dnsmasq[0].server='223.5.5.5' 2>/dev/null
                uci set dhcp.@dnsmasq[0].noresolv=1 2>/dev/null
                uci set dhcp.@dnsmasq[0].cache_size=10000 2>/dev/null
                uci commit dhcp 2>/dev/null
                /etc/init.d/dnsmasq restart 2>/dev/null
                # 连接跟踪
                echo 65536 > /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null
                if [ -f /sys/module/nf_conntrack/parameters/hashsize ]; then
                    echo 16384 > /sys/module/nf_conntrack/parameters/hashsize 2>/dev/null
                fi
                echo 7200 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null
                echo 30 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_close_wait 2>/dev/null
                echo 30 > /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_fin_wait 2>/dev/null
                # 缓冲区
                echo 16777216 > /proc/sys/net/core/rmem_max 2>/dev/null
                echo 16777216 > /proc/sys/net/core/wmem_max 2>/dev/null
                echo 262144 > /proc/sys/net/core/rmem_default 2>/dev/null
                echo 262144 > /proc/sys/net/core/wmem_default 2>/dev/null
                echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
                echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
                echo 5000 > /proc/sys/net/core/netdev_max_backlog 2>/dev/null
                echo 2048 > /proc/sys/net/core/somaxconn 2>/dev/null
                # WiFi队列 (非sysctl, 走rc.local)
                for iface in ath0 ath1; do
                    [ -d "/sys/class/net/$iface" ] && echo 1000 > /sys/class/net/$iface/tx_queue_len 2>/dev/null
                done
                # 内核内存
                echo 8192 > /proc/sys/vm/min_free_kbytes 2>/dev/null
                echo 0 > /proc/sys/vm/overcommit_memory 2>/dev/null
                echo 10 > /proc/sys/vm/swappiness 2>/dev/null

                # ===== 2. B8持久化: sysctl values 到 /etc/sysctl.d/99-clash-rs.conf =====
                _persist_sysctl_conf

                # ===== 3. B8持久化: 非sysctl项到 /etc/rc.local =====
                _persist_rc_local

                pl "${G}  网络参数优化 v4 完成 (已持久化, 重启不丢失)${N}"
                pl "  ${Y}sysctl持久化: /etc/sysctl.d/99-clash-rs.conf${N}"
                pl "  ${Y}rc.local持久化: cpufreq/RPS/tx_queue_len${N}"
                pl "  ${Y}dnsmasq持久化: uci dhcp (已commit)${N}"
                ;;
            14)
                # C11: 健康检查参数 (间隔/超时) 持久化
                local cur_int=$(get_health_interval)
                local cur_to=$(get_health_timeout)
                pl "${C}  健康检查参数${N}"
                pl "  当前: 间隔=${G}${cur_int}s${N}  超时=${G}${cur_to}s${N}"
                pl "  ${Y}推荐: 间隔 60~600s, 超时 3~10s${N}"
                pl ""
                pl "  ${W}1${N}. 修改检测间隔 (当前 ${cur_int}s)"
                pl "  ${W}2${N}. 修改检测超时 (当前 ${cur_to}s)"
                pl "  ${W}3${N}. 恢复默认 (间隔300s, 超时5s)"
                pl "  ${W}0${N}. 返回"
                printf "  请选择: "
                read hc_choice
                case "$hc_choice" in
                    1)
                        printf "  输入间隔秒数 (30~3600): "
                        read v
                        case "$v" in
                            [0-9]*)
                                if [ "$v" -ge 30 ] 2>/dev/null && [ "$v" -le 3600 ] 2>/dev/null; then
                                    echo "$v" > $HEALTH_INTERVAL_FILE
                                    pl "${G}  已设置间隔: ${v}s${N}"
                                    pl "${Y}  下次健康检查周期生效${N}"
                                else
                                    pl "${R}  范围 30~3600${N}"
                                fi
                                ;;
                            *) pl "${R}  无效${N}" ;;
                        esac
                        ;;
                    2)
                        printf "  输入超时秒数 (1~30): "
                        read v
                        case "$v" in
                            [0-9]*)
                                if [ "$v" -ge 1 ] 2>/dev/null && [ "$v" -le 30 ] 2>/dev/null; then
                                    echo "$v" > $HEALTH_TIMEOUT_FILE
                                    pl "${G}  已设置超时: ${v}s${N}"
                                    pl "${Y}  下次健康检查周期生效${N}"
                                else
                                    pl "${R}  范围 1~30${N}"
                                fi
                                ;;
                            *) pl "${R}  无效${N}" ;;
                        esac
                        ;;
                    3)
                        rm -f $HEALTH_INTERVAL_FILE $HEALTH_TIMEOUT_FILE 2>/dev/null
                        pl "${G}  已恢复默认: 间隔300s 超时5s${N}"
                        ;;
                    0|"") ;;
                    *) pl "${R}  无效${N}" ;;
                esac
                sleep 1
                ;;
            15)
                # C1: 配置备份与回滚子菜单
                while true; do
                    printf "\n"
                    line
                    pl "${C}  配置备份与回滚${N}"
                    line
                    pl "  ${W}1${N}. 立即备份当前配置"
                    pl "  ${W}2${N}. 查看备份列表"
                    pl "  ${W}3${N}. 从备份恢复"
                    pl "  ${W}4${N}. 备份二进制 (cc binbak)"
                    pl "  ${W}5${N}. 查看二进制备份列表"
                    pl "  ${W}6${N}. 从二进制备份恢复"
                    pl "  ${W}0${N}. 返回上级菜单"
                    printf "\n  请选择: "
                    read bk_choice
                    case "$bk_choice" in
                        1) _backup_create; pause_for_input ;;
                        2) _backup_list; pause_for_input ;;
                        3) _backup_restore; pause_for_input ;;
                        4) _binbak_create; pause_for_input ;;
                        5) _binbak_list; pause_for_input ;;
                        6) _binbak_restore; pause_for_input ;;
                        0) break ;;
                        *) pl "${R}  无效选择${N}" ;;
                    esac
                done
                ;;
            16)
                # 批次9: HTTP代理端口热改
                pl "${C}  HTTP代理端口 (port)${N}"
                pl "  当前: ${G}${CUR_PORT:-未设置}${N}"
                pl "  ${Y}注意: clash-rs HTTP代理端口, 修改后立即热生效并持久化${N}"
                printf "  新端口 (1-65535, 回车=取消): "
                read np
                case "$np" in
                    ''|*[!0-9]*) pl "${R}  已取消或无效${N}" ;;
                    *)
                        if [ "$np" -ge 1 ] 2>/dev/null && [ "$np" -le 65535 ] 2>/dev/null; then
                            do_patch port "$np"
                        else
                            pl "${R}  端口范围 1-65535${N}"
                        fi
                        ;;
                esac
                sleep 1
                ;;
            17)
                # 批次9: IPv6开关
                pl "${C}  IPv6 开关 (顶层)${N}"
                pl "  当前: ${G}${CUR_IPV6:-未设置}${N}"
                pl "  ${Y}说明: 顶层ipv6控制IPv6出站连接, 与dns.ipv6独立${N}"
                pl "  ${Y}      IPv6服务器必需开启, 否则无法连接${N}"
                local newv
                [ "$CUR_IPV6" = "true" ] && newv="false" || newv="true"
                printf "  切换为 %s? (y/N): " "$newv"
                read confirm
                case "$confirm" in
                    y|Y) do_patch ipv6 "$newv" ;;
                    *) pl "  已取消" ;;
                esac
                sleep 1
                ;;
            18)
                # 批次9: 日志级别
                pl "${C}  日志级别 (log-level)${N}"
                pl "  当前: ${G}${CUR_LOGLVL:-未设置}${N}"
                pl "  可选: trace / debug / info / warning / error / silent"
                pl "  ${Y}推荐: info (日常) / debug (排错) / warning (生产)${N}"
                printf "  新级别: "
                read nl
                case "$nl" in
                    trace|debug|info|warning|error|silent) do_patch log-level "$nl" ;;
                    *) pl "${R}  无效级别${N}" ;;
                esac
                sleep 1
                ;;
            19)
                # 批次9: 允许局域网
                pl "${C}  允许局域网 (allow-lan)${N}"
                pl "  当前: ${G}${CUR_ALLOWLAN:-未设置}${N}"
                local newv
                [ "$CUR_ALLOWLAN" = "true" ] && newv="false" || newv="true"
                printf "  切换为 %s? (y/N): " "$newv"
                read confirm
                case "$confirm" in
                    y|Y) do_patch allow-lan "$newv" ;;
                    *) pl "  已取消" ;;
                esac
                sleep 1
                ;;
            20)
                # experimental 子菜单: anytls-duplex-buffer-size / tcp-buffer-size / ignore-resolve-fail
                while true; do
                    printf "\n"
                    line
                    pl "${C}  experimental 实验性配置${N}"
                    line
                    pl "  ${W}1${N}. anytls-duplex-buffer-size: ${G}${CUR_ANYTLS_BUF:-默认}${N}"
                    pl "      ${Y}AnyTLS协议双工缓冲区(KB), 仅影响AnyTLS节点, SS/Trojan不受影响${N}"
                    pl "      ${Y}常用值: 64/128/256/512, 范围16-8192${N}"
                    pl "  ${W}2${N}. tcp-buffer-size:         ${G}${CUR_TCP_BUF:-默认}${N}"
                    pl "      ${Y}TCP连接缓冲区大小(KB), 影响所有TCP代理连接的吞吐与内存${N}"
                    pl "      ${Y}值大吞吐高但占内存, 路由器推荐64-256, 范围16-8192${N}"
                    pl "  ${W}3${N}. ignore-resolve-fail:    ${G}${CUR_IGNORERESOLVE:-默认}${N}"
                    pl "      ${Y}DNS解析失败时是否忽略(true=继续代理, false=拒绝连接)${N}"
                    pl "      ${Y}建议false以暴露DNS故障, true可能导致节点静默失效${N}"
                    pl "  ${W}0${N}. 返回"
                    printf "\n  请选择: "
                    read exp_choice
                    case "$exp_choice" in
                        1)
                            printf "  新值(KB, 16-8192, 回车=取消): "; read nb
                            case "$nb" in
                                ''|*[!0-9]*) pl "${R}  已取消或无效${N}" ;;
                                *)
                                    if [ "$nb" -ge 16 ] 2>/dev/null && [ "$nb" -le 8192 ] 2>/dev/null; then
                                        _patch_yaml_block "experimental" "anytls-duplex-buffer-size" "$nb"
                                        CUR_ANYTLS_BUF="$nb"
                                    else
                                        pl "${R}  范围 16-8192${N}"
                                    fi
                                    ;;
                            esac
                            sleep 1
                            ;;
                        2)
                            printf "  新值(KB, 16-8192, 回车=取消): "; read nb
                            case "$nb" in
                                ''|*[!0-9]*) pl "${R}  已取消或无效${N}" ;;
                                *)
                                    if [ "$nb" -ge 16 ] 2>/dev/null && [ "$nb" -le 8192 ] 2>/dev/null; then
                                        _patch_yaml_block "experimental" "tcp-buffer-size" "$nb"
                                        CUR_TCP_BUF="$nb"
                                    else
                                        pl "${R}  范围 16-8192${N}"
                                    fi
                                    ;;
                            esac
                            sleep 1
                            ;;
                        3)
                            printf "  新值(true/false, 回车=取消): "; read nb
                            case "$nb" in
                                true|false) _patch_yaml_block "experimental" "ignore-resolve-fail" "$nb"; CUR_IGNORERESOLVE="$nb" ;;
                                *) pl "${R}  仅 true/false${N}" ;;
                            esac
                            sleep 1
                            ;;
                        0) break ;;
                        *) pl "${R}  无效选择${N}" ;;
                    esac
                done
                ;;
            0) break ;;
            *) pl "${R}  无效选择${N}" ;;
        esac
    done
}

# ============================================================
# 版本与信息 (cc version / 菜单4)
# ============================================================

show_version() {
    line
    pl "${W}  cc 脚本版本: ${G}v${CC_VERSION}${N}"
    line
    # clash-rs 二进制版本
    if [ -x "$CLASH_BIN" ]; then
        BIN_VER=$($CLASH_BIN -v 2>/dev/null | head -1)
        [ -z "$BIN_VER" ] && BIN_VER=$($CLASH_BIN --version 2>/dev/null | head -1)
        pl "  clash-rs 二进制: ${G}${BIN_VER:-未知}${N}"
    else
        pl "  clash-rs 二进制: ${R}未找到 ($CLASH_BIN)${N}"
    fi
    # 配置文件
    if [ -f "$CONFIG" ]; then
        CFG_SIZE=$(wc -c < "$CONFIG" 2>/dev/null)
        CFG_MTIME=$(ls -l "$CONFIG" 2>/dev/null | awk '{print $6,$7,$8}')
        pl "  配置文件: ${G}${CONFIG}${N} (${CFG_SIZE}B, ${CFG_MTIME})"
    else
        pl "  配置文件: ${R}未找到${N}"
    fi
    # init.d 脚本
    if [ -f "$INIT_SCRIPT" ]; then
        pl "  init脚本: ${G}${INIT_SCRIPT}${N}"
    else
        pl "  init脚本: ${R}未找到${N}"
    fi
    # 关键参数
    pl "  ${C}关键参数:${N}"
    pl "    API: ${API_HOST}:${API_PORT}  密钥: ${SECRET}"
    pl "    代理端口: mixed=7890 redir=7892 tproxy=7893 dns=1053"
    pl "    PID文件: ${PID_FILE}"
    pl "    日志文件: ${LOG_FILE}"
    # 运行状态摘要
    if is_running; then
        PID=$(get_pid)
        RSS=$(get_rss)
        UPTIME=$(get_uptime)
        PROXY=$(get_proxy_now)
        pl "  ${C}运行状态:${N}"
        pl "    PID: $PID  内存: ${RSS}MB  运行: $UPTIME"
        pl "    当前节点: ${G}${PROXY:-未知}${N}"
    else
        pl "  ${C}运行状态:${N} ${R}未运行${N}"
    fi
    # 系统信息
    pl "  ${C}系统信息:${N}"
    KERNEL=$(uname -r 2>/dev/null)
    ARCH=$(uname -m 2>/dev/null)
    LOADAVG=$(cat /proc/loadavg 2>/dev/null | awk '{print $1,$2,$3}')
    UPTIME_SYS=$(cat /proc/uptime 2>/dev/null | awk '{printf "%.0f", $1/86400}')
    pl "    内核: ${KERNEL}  架构: ${ARCH}"
    pl "    负载: ${LOADAVG}  系统运行: ${UPTIME_SYS}天"
    MEM_AVAIL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $7/1024}')
    MEM_TOTAL=$(free 2>/dev/null | awk '/^Mem:/{printf "%.0f", $2/1024}')
    pl "    内存: 可用${MEM_AVAIL}MB / 总${MEM_TOTAL}MB"
    line
}

# ============================================================
# 主菜单 (ShellCrash风格)
# ============================================================

# ============================================================
# DNS 模式切换 (cc dns-mode)
# ============================================================
do_dns_mode() {
    local cfg=/etc/clash-rs/config.yaml
    local mode="${1:-}"

    _show_dns_mode() {
        if grep -q 'tls://'  2>/dev/null; then
            echo "encrypted (DoT+DoH)"
        elif grep -q 'dns-query'  2>/dev/null; then
            echo "doh"
        else
            echo "udp"
        fi
    }

    _apply_dns_mode() {
        local m=$1
        cp $cfg ${cfg}.bak.dnsmode.$(date +%s) 2>/dev/null

        case "$m" in
            udp)
                # 删除 nameserver 段中的 DoH/DoT 行（只删 - https 和 - tls 开头的行）
                sed -i '/^  nameserver:/,/^  [a-z]/{/- https/d; /- tls/d}' $cfg
                # fallback 段：把 DoH/DoT 替换为 UDP
                sed -i '/^  fallback:/,/^  [a-z]/{s|- https://[^ ]*|- 1.1.1.1|; s|- tls://[^ ]*|- 8.8.8.8|}' $cfg
                ;;
            doh)
                # fallback 段：把 UDP 替换为 DoH
                sed -i '/^  fallback:/,/^  [a-z]/{s|- 1.1.1.1|- https://1.1.1.1/dns-query|; s|- 8.8.8.8|- https://8.8.8.8/dns-query|}' $cfg
                ;;
            encrypted)
                # fallback 段：把 UDP 替换为 DoT+DoH
                sed -i '/^  fallback:/,/^  [a-z]/{s|- 1.1.1.1|- tls://1.1.1.1:853|; s|- 8.8.8.8|- https://8.8.8.8/dns-query|}' $cfg
                ;;
        esac

        # 热重载
        curl -s -X PUT http://127.0.0.1:9090/config -H "Authorization: Bearer clashrs2026" -H "Content-Type: application/json" -d "{"path":"$cfg"}" >/dev/null 2>&1
    }

    if [ -n "$mode" ]; then
        _apply_dns_mode "$mode"
        pl "DNS mode: ${G}$mode"
        return
    fi

    while true; do
        local cur_mode
        cur_mode=$(_show_dns_mode)
        printf "
"
        line
        pl "${C}  DNS Mode Switch  current: ${G}${cur_mode}"
        line
        pl "  1. UDP (119/223 + 1.1.1.1/8.8.8.8)"
        pl "     stable, never disconnects (like normal router)"
        pl "     no encryption, ISP can see queries"
        pl "  2. DoH (1.1.1.1/8.8.8.8 over HTTPS)"
        pl "     encrypted, anti-pollution"
        pl "     TCP long-conn may disconnect"
        pl "  3. DoT+DoH (tls:853 + DoH)"
        pl "     strongest encryption"
        pl "     port 853 may be blocked by ISP"
        pl "  0. Back"
        line
        printf "
  Choice: "
        read dm_choice
        case "$dm_choice" in
            1) _apply_dns_mode udp; pl "Switched to UDP"; pause_for_input ;;
            2) _apply_dns_mode doh; pl "Switched to DoH"; pause_for_input ;;
            3) _apply_dns_mode encrypted; pl "Switched to DoT+DoH"; pause_for_input ;;
            0) break ;;
            *) pl "Invalid" ;;
        esac
    done
}


# ============================================================
# 入口
# ============================================================

# ============================================================
# 全量备份/恢复 + lastgood 启动
# ============================================================
_full_backup() {
    local bakdir="/etc/clash-rs/fullbackup"
    local ts=$(date +%Y%m%d-%H%M%S)
    local target="$bakdir/$ts"
    mkdir -p "$target" 2>/dev/null
    local cnt=0
    for f in /etc/clash-rs/config.yaml /etc/clash-rs/config.yaml.lastgood /etc/clash-rs/cc.sh /etc/clash-rs/mem_threshold /etc/clash-rs/cn_ip.txt /etc/init.d/clash-rs /usr/bin/clash-watchdog /usr/bin/fix-nodes /usr/bin/fix-tx-queue /usr/bin/safe-ntp /usr/bin/clash-logrotate /usr/bin/clash-wrapper /etc/rc.local /etc/sysctl.conf /etc/crontabs/root; do
        if [ -f "$f" ]; then
            local dest="$target$f"
            mkdir -p "$(dirname "$dest")" 2>/dev/null
            cp "$f" "$dest" 2>/dev/null && cnt=$((cnt+1))
        fi
    done
    echo "backup_time=$ts config_md5=$(md5sum /etc/clash-rs/config.yaml 2>/dev/null | awk '{print $1}') files=$cnt" > "$target/info.txt"
    local keep=5
    local n=$(ls -1d "$bakdir"/*/ 2>/dev/null | wc -l)
    if [ "$n" -gt "$keep" ]; then
        ls -1d "$bakdir"/*/ 2>/dev/null | sort | head -$((n-keep)) | while read d; do rm -rf "$d" 2>/dev/null; done
    fi
    local sz=$(du -sh "$target" 2>/dev/null | awk '{print $1}')
    pl "${G}  全量备份完成: $cnt 文件, ${sz:-?}${N}"
    pl "  目录: $target"
}

_full_backup_list() {
    local bakdir="/etc/clash-rs/fullbackup"
    [ ! -d "$bakdir" ] && { pl "${R}  无全量备份${N}"; return 1; }
    local files=$(ls -1d "$bakdir"/*/ 2>/dev/null | sort -r)
    [ -z "$files" ] && { pl "${R}  无全量备份${N}"; return 1; }
    pl "${C}  全量备份列表 (最新在前)${N}"
    line
    local i=0
    echo "$files" | while read d; do
        [ -z "$d" ] && continue
        i=$((i+1))
        local ts=$(basename "$d")
        local info="$d/info.txt"
        local cnt=$(grep files= "$info" 2>/dev/null | awk -F= '{print $2}')
        local sz=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
        pl "  ${W}$i${N}. $ts (${cnt:-?}文件, ${sz:-?})"
    done
    line
}

_full_restore() {
    local target="$1"
    local bakdir="/etc/clash-rs/fullbackup"
    if [ -z "$target" ]; then
        _full_backup_list
        printf "\n  输入序号恢复 (0=取消): "
        read fr_choice
        [ -z "$fr_choice" ] || [ "$fr_choice" = "0" ] && { pl "  取消"; return 0; }
        local files=$(ls -1d "$bakdir"/*/ 2>/dev/null | sort -r)
        target=$(echo "$files" | sed -n "${fr_choice}p" | sed 's|/$||')
        [ -z "$target" ] && { pl "${R}  序号超出范围${N}"; return 1; }
    fi
    [ ! -d "$target" ] && { pl "${R}  备份不存在: $target${N}"; return 1; }
    pl "${Y}  即将从 $(basename $target) 恢复全部文件${N}"
    pl "  ${Y}当前文件会被覆盖, 确认? (y/N)${N}"
    printf "  > "
    read confirm
    case "$confirm" in y|Y) ;; *) pl "  取消"; return 0 ;; esac
    local cnt=0
    for f in etc/clash-rs/config.yaml etc/clash-rs/config.yaml.lastgood etc/clash-rs/cc.sh etc/clash-rs/mem_threshold etc/clash-rs/cn_ip.txt etc/init.d/clash-rs usr/bin/clash-watchdog usr/bin/fix-nodes usr/bin/fix-tx-queue usr/bin/safe-ntp usr/bin/clash-logrotate usr/bin/clash-wrapper etc/rc.local etc/sysctl.conf etc/crontabs/root; do
        [ -f "$target/$f" ] && cp "$target/$f" "/$f" 2>/dev/null && cnt=$((cnt+1))
    done
    chmod 755 /etc/init.d/clash-rs /usr/bin/clash-watchdog /usr/bin/fix-nodes /usr/bin/fix-tx-queue /usr/bin/safe-ntp /usr/bin/clash-logrotate /usr/bin/clash-wrapper /etc/clash-rs/cc.sh /etc/rc.local 2>/dev/null
    pl "${G}  恢复完成: $cnt 文件${N}"
    pl "  ${Y}建议重启: cc restart${N}"
}

_start_lastgood() {
    local lastgood="/etc/clash-rs/config.yaml.lastgood"
    [ ! -s "$lastgood" ] && { pl "${R}  无上次成功配置${N}"; return 1; }
    if diff -q "$CONFIG" "$lastgood" >/dev/null 2>&1; then
        pl "${G}  当前配置=上次成功配置, 直接启动${N}"
    else
        pl "${Y}  当前配置与上次成功配置不同, 将从 lastgood 启动${N}"
        pl "  当前: $(md5sum $CONFIG 2>/dev/null | awk '{print $1}')"
        pl "  上次: $(md5sum $lastgood 2>/dev/null | awk '{print $1}')"
        printf "  确认? (y/N): "
        read confirm
        case "$confirm" in y|Y) ;; *) pl "  取消"; return 0 ;; esac
        cp "$CONFIG" "$CONFIG.before" 2>/dev/null
        cp "$lastgood" "$CONFIG" 2>/dev/null
    fi
    pl "${C}  从上次成功配置启动...${N}"
    /etc/init.d/clash-rs restart 2>&1 | tail -3
    sleep 3
    if is_running; then
        pl "${G}  启动成功 (PID=$(get_pid))${N}"
        pl "  节点: $(get_proxy_now)"
        pl "  内存: $(get_rss)MB"
    else
        pl "${R}  启动失败, 恢复原配置${N}"
        cp "$CONFIG.before" "$CONFIG" 2>/dev/null
        /etc/init.d/clash-rs restart 2>&1 | tail -3
    fi
}


# ============================================================
# 强制完整备份 (cc fullbackup-all) - 包含二进制和mmdb
# ============================================================
_full_backup_all() {
    local bakdir="/etc/clash-rs/fullbackup"
    local ts=$(date +%Y%m%d-%H%M%S)
    local target="$bakdir/$ts"
    mkdir -p "$target" 2>/dev/null

    pl "${R}  ========================================${N}"
    pl "${R}  警告: 强制完整备份${N}"
    pl "${R}  ========================================${N}"
    pl "${Y}  此操作会备份以下大文件:${N}"
    pl "    - clash-rs 二进制 (15.6M)"
    pl "    - country.mmdb (8.8M)"
    pl "    - 所有脚本+配置 (~476K)"
    pl "${Y}  总大小约 25M, 闪存仅 71M${N}"
    pl "${Y}  频繁操作会减少闪存寿命!${N}"
    pl "${Y}  仅在核心更新/重大修改后使用${N}"
    pl ""
    printf "${Y}  确认强制完整备份? (y/N): ${N}"
    read confirm
    case "$confirm" in
        y|Y) ;;
        *) pl "  取消"; return 0 ;;
    esac

    local cnt=0
    for f in /etc/clash-rs/config.yaml /etc/clash-rs/config.yaml.lastgood /etc/clash-rs/cc.sh /etc/clash-rs/clash-rs /etc/clash-rs/mem_threshold /etc/clash-rs/country.mmdb /etc/clash-rs/cn_ip.txt /etc/init.d/clash-rs /usr/bin/clash-watchdog /usr/bin/fix-nodes /usr/bin/fix-tx-queue /usr/bin/safe-ntp /usr/bin/clash-logrotate /usr/bin/clash-wrapper /etc/rc.local /etc/sysctl.conf /etc/crontabs/root; do
        if [ -f "$f" ]; then
            local dest="$target$f"
            mkdir -p "$(dirname "$dest")" 2>/dev/null
            cp "$f" "$dest" 2>/dev/null && cnt=$((cnt+1))
        fi
    done
    echo "backup_time=$ts config_md5=$(md5sum /etc/clash-rs/config.yaml 2>/dev/null | awk '{print $1}') files=$cnt type=full" > "$target/info.txt"
    local keep=2
    local n=$(ls -1d "$bakdir"/*/ 2>/dev/null | wc -l)
    if [ "$n" -gt "$keep" ]; then
        ls -1d "$bakdir"/*/ 2>/dev/null | sort | head -$((n-keep)) | while read d; do rm -rf "$d" 2>/dev/null; done
    fi
    local sz=$(du -sh "$target" 2>/dev/null | awk '{print $1}')
    local avail=$(df -h / | tail -1 | awk '{print $4}')
    pl "${G}  完整备份完成: $cnt 文件, ${sz:-?}${N}"
    pl "  目录: $target"
    pl "  剩余空间: $avail"
}



# ============================================================
# 订阅管理 (cc sub)
# ============================================================
_subfile='/etc/clash-rs/subscriptions.list'

_sub_menu() {
    touch "$_subfile" 2>/dev/null
    while true; do
        local cnt=$(wc -l < "$_subfile" 2>/dev/null)
        printf '\n'
        line
        pl "${C}  订阅管理${N}  ${Y}已保存 $cnt 个订阅${N}"
        line
        pl "  ${W}1${N}. 添加订阅链接"
        pl "  ${W}2${N}. 列出订阅"
        pl "  ${W}3${N}. 更新订阅"
        pl "  ${W}4${N}. 删除订阅"
        pl "  ${W}5${N}. 导入单节点"
        pl "  ${W}6${N}. 自动更新设置"
        pl "  ${W}0${N}. 返回"
        line
        printf '\n  选择: '
        read sm_choice
        case "$sm_choice" in
            1) _sub_add ;;
            2) _sub_list ;;
            3) _sub_update ;;
            4) _sub_del ;;
            5) _sub_single_input ;;
            6) _sub_auto_update ;;
            0) break ;;
            *) pl "${R}  无效${N}" ;;
        esac
    done
}

_sub_add() {
    printf "  ${Y}订阅链接: ${N}"
    read url
    [ -z "$url" ] && { pl "  取消"; return; }
    if grep -qF "$url" "$_subfile" 2>/dev/null; then
        pl "${R}  已存在${N}"
        return
    fi
    echo "$url" >> "$_subfile"
    pl "${G}  已添加${N}"
    printf "  ${Y}立即下载? (y/N): ${N}"
    read confirm
    case "$confirm" in y|Y) _sub_update_one "$url" ;; esac
}

_sub_list() {
    [ ! -s "$_subfile" ] && { pl "${R}  无订阅${N}"; return; }
    pl "${C}  订阅列表${N}"
    line
    local i=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        i=$((i+1))
        local short=$(echo "$line" | cut -c1-60)
        pl "  ${W}$i${N}. ${short}..."
    done < "$_subfile"
    line
}

_sub_update() {
    [ ! -s "$_subfile" ] && { pl "${R}  无订阅${N}"; return; }

    # 列出所有订阅，让用户选择更新哪个
    local cnt=$(grep -cE '.' "$_subfile" 2>/dev/null)
    [ "$cnt" -eq 0 ] && { pl "${R}  无订阅${N}"; return; }

    _sub_list
    echo ""
    printf "  选择更新 (1-${cnt}, 回车=全部, 0=取消): "
    read sel
    [ "$sel" = "0" ] && return

    local total=0
    local tmpnodes='/tmp/sub_all_nodes.txt'
    > "$tmpnodes"

    if [ -n "$sel" ] && [ "$sel" -ge 1 ] 2>/dev/null && [ "$sel" -le "$cnt" ]; then
        # 更新单个订阅（用 sed 行号取指定行）
        local url=$(sed -n "${sel}p" "$_subfile")
        [ -z "$url" ] && { pl "${R}  无效选择${N}"; rm -f "$tmpnodes"; return; }
        pl "${C}  更新第 ${sel} 个订阅...${N}"
        local nodes=$(_sub_download_one "$url")
        if [ -n "$nodes" ]; then
            echo "$nodes" >> "$tmpnodes"
            local n=$(echo "$nodes" | grep -c 'name:')
            total=$n
            pl "  ${G}OK${N} ($n 节点)"
        else
            pl "  ${R}FAIL${N} $(echo "$url" | cut -c1-50)..."
            rm -f "$tmpnodes"
            return
        fi
    else
        # 更新全部
        pl "${C}  更新所有订阅...${N}"
        while IFS= read -r url; do
            [ -z "$url" ] && continue
            local nodes=$(_sub_download_one "$url")
            if [ -n "$nodes" ]; then
                echo "$nodes" >> "$tmpnodes"
                local n=$(echo "$nodes" | grep -c 'name:')
                total=$((total+n))
                pl "  ${G}OK${N} $(echo "$url" | cut -c1-50)... (${n}节点)"
            else
                pl "  ${R}FAIL${N} $(echo "$url" | cut -c1-50)..."
            fi
        done < "$_subfile"
    fi

    if [ "$total" -eq 0 ]; then
        pl "${R}  无有效节点${N}"
        rm -f "$tmpnodes"
        return
    fi
    pl "${Y}  共 $total 个节点, 替换到配置中生效? (y/N)${N}"
    printf '  > '
    read confirm
    case "$confirm" in y|Y) ;; *) pl "  取消"; rm -f "$tmpnodes"; return ;; esac
    local bakfile="$CONFIG.bak.sub.$(date +%s)"
    cp "$CONFIG" "$bakfile" 2>/dev/null

    # 解析节点名（URL解码+过滤无用节点名）
    local node_names=""
    local real_nodes=""
    while IFS= read -r line; do
        echo "$line" | grep -qE 'name:.*(剩余|到期|重置|套餐|%E5%89%A9|%E5%88%B0|%E9%87%8D|%E5%A5%97)' && continue
        local name=$(echo "$line" | sed -n 's/.*name: "\([^"]*\)".*/\1/p')
        [ -z "$name" ] && continue
        local decoded=$(printf "%b" "$(echo "$name" | sed 's/%/\\\\x/g')" 2>/dev/null)
        [ -z "$decoded" ] && decoded="$name"
        echo "$decoded" | grep -qE '剩余|到期|重置|套餐|GB|天' && continue
        local new_line=$(name="$name" decoded="$decoded" awk 'BEGIN{a="name: \"" ENVIRON["name"] "\""; b="name: \"" ENVIRON["decoded"] "\""} {i=index($0,a); if(i>0){print substr($0,1,i-1) b substr($0,i+length(a))} else print}' 2>/dev/null)
        [ -z "$new_line" ] && new_line="$line"
        # 去重：节点名已在列表则跳过（防止 duplicated proxy name 崩溃）
        echo "$node_names" | grep -Fqx "$decoded" && continue
        node_names="$node_names
$decoded"
        real_nodes="$real_nodes
$new_line"
    done < "$tmpnodes"

    # 重建 config（替换 proxies 段，保留其余配置）
    local header=$(sed -n '1,/^proxies:/p' "$CONFIG" | sed '$d')
    local rules=$(sed -n '/^rules:/,$p' "$CONFIG")
    {
        echo "$header"
        echo ""
        echo "proxies:"
        echo "$real_nodes" | grep -v '^$'
        echo ""
        echo "proxy-groups:"
        echo "  - name: PROXY"
        echo "    type: select"
        echo "    proxies:"
        echo "      - AUTO"
        echo "      - DIRECT"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do
            echo "      - \"$n\""
        done
        echo ""
        echo "  - name: AUTO"
        echo "    type: url-test"
        echo "    url: http://cp.cloudflare.com/generate_204"
        echo "    interval: 600"
        echo "    tolerance: 100"
        echo "    timeout: 5"
        echo "    proxies:"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do
            echo "      - \"$n\""
        done
        echo ""
        echo "$rules"
    } > "$CONFIG.tmp" 2>/dev/null

    if [ ! -s "$CONFIG.tmp" ]; then
        pl "${R}  配置生成失败, 已恢复备份${N}"
        cp "$bakfile" "$CONFIG" 2>/dev/null
        rm -f "$tmpnodes" "$CONFIG.tmp"
        return
    fi
    mv "$CONFIG.tmp" "$CONFIG" 2>/dev/null
    if _reload_config; then
        local ts=$(date '+%H:%M:%S')
        pl "${G}  [${ts}] 更新成功, $total 个节点已替换到配置中${N}"
    else
        pl "${R}  重启 clash-rs 失败, 已恢复备份 (可用 cc restart 手动重试)${N}"
        cp "$bakfile" "$CONFIG" 2>/dev/null
    fi
    rm -f "$tmpnodes"
}

_sub_update_one() {
    local url="$1"
    local nodes=$(_sub_download_one "$url")
    if [ -z "$nodes" ]; then
        pl "${R}  下载失败${N}"
        return
    fi
    local n=$(echo "$nodes" | grep -c 'name:')
    pl "${G}  下载成功: $n 个节点${N}"
    pl "${Y}  替换到配置中生效? (y/N)${N}"
    printf '  > '
    read confirm
    case "$confirm" in [Yy]*) ;; *) return ;; esac

    local bakfile="$CONFIG.bak.sub.$(date +%s)"
    cp "$CONFIG" "$bakfile" 2>/dev/null

    # 解析节点名（URL解码+过滤+去重）
    local node_names=""
    local real_nodes=""
    local tmpnodes='/tmp/sub_one_nodes.txt'
    echo "$nodes" > "$tmpnodes"
    while IFS= read -r line; do
        echo "$line" | grep -qE 'name:.*(剩余|到期|重置|套餐|%E5%89%A9|%E5%88%B0|%E9%87%8D|%E5%A5%97)' && continue
        local name=$(echo "$line" | sed -n 's/.*name: "\([^"]*\)".*/\1/p')
        [ -z "$name" ] && continue
        local decoded=$(printf "%b" "$(echo "$name" | sed 's/%/\\\\x/g')" 2>/dev/null)
        [ -z "$decoded" ] && decoded="$name"
        echo "$decoded" | grep -qE '剩余|到期|重置|套餐|GB|天' && continue
        local new_line=$(name="$name" decoded="$decoded" awk 'BEGIN{a="name: \"" ENVIRON["name"] "\""; b="name: \"" ENVIRON["decoded"] "\""} {i=index($0,a); if(i>0){print substr($0,1,i-1) b substr($0,i+length(a))} else print}' 2>/dev/null)
        [ -z "$new_line" ] && new_line="$line"
        echo "$node_names" | grep -Fqx "$decoded" && continue
        node_names="$node_names
$decoded"
        real_nodes="$real_nodes
$new_line"
    done < "$tmpnodes"
    rm -f "$tmpnodes"

    # 重建 config
    local header=$(sed -n '1,/^proxies:/p' "$CONFIG" | sed '$d')
    local rules=$(sed -n '/^rules:/,$p' "$CONFIG")
    {
        echo "$header"
        echo ""
        echo "proxies:"
        echo "$real_nodes" | grep -v '^$'
        echo ""
        echo "proxy-groups:"
        echo "  - name: PROXY"
        echo "    type: select"
        echo "    proxies:"
        echo "      - AUTO"
        echo "      - DIRECT"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do echo "      - \"$n\""; done
        echo ""
        echo "  - name: AUTO"
        echo "    type: url-test"
        echo "    url: http://cp.cloudflare.com/generate_204"
        echo "    interval: 600"
        echo "    tolerance: 100"
        echo "    timeout: 5"
        echo "    proxies:"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do echo "      - \"$n\""; done
        echo ""
        echo "$rules"
    } > "$CONFIG.tmp" 2>/dev/null

    if [ ! -s "$CONFIG.tmp" ]; then
        pl "${R}  配置生成失败${N}"
        cp "$bakfile" "$CONFIG" 2>/dev/null
        return
    fi
    mv "$CONFIG.tmp" "$CONFIG" 2>/dev/null
    _reload_config && pl "${G}  [$(date '+%H:%M:%S')] OK${N}" || pl "${R}  FAIL${N}"
}

_sub_download_one() {
    local url="$1"
    local tmp='/tmp/sub_dl.txt'
    local host=$(echo "$url" | sed -n 's|https://\([^/:]*\).*|\1|p')
    local resolve_opts=""
    local proxy_opts=""

    # 绕过 fake-ip: 先用直连 DNS 解析域名，再用 --resolve 下载
    if [ -n "$host" ]; then
        # 尝试 223.5.5.5（阿里 DNS，对国外 CDN 兼容性好）
        local real_ip=$(nslookup "$host" 223.5.5.5 2>/dev/null | grep 'Address' | grep -v '223.5' | grep -v '127.0.0' | head -1 | awk '{print $NF}')
        if [ -z "$real_ip" ] || [ "$real_ip" = "198.18.0.24" ]; then
            # 再试 114.114.114.114
            real_ip=$(nslookup "$host" 114.114.114.114 2>/dev/null | grep 'Address' | grep -v '114.114' | grep -v '127.0.0' | head -1 | awk '{print $NF}')
        fi
        if [ -n "$real_ip" ] && [ "$real_ip" != "198.18.0.24" ]; then
            resolve_opts="--resolve ${host}:443:${real_ip}"
        else
            # 直连 DNS 解析失败，走代理下载（订阅域名多在境外 CDN）
            proxy_opts="-x http://127.0.0.1:7890"
        fi
    fi

    curl -s -L --connect-timeout 15 --max-time 30 $proxy_opts $resolve_opts -o "$tmp" "$url" 2>/dev/null
    [ ! -s "$tmp" ] && { echo ''; return; }
    local first=$(head -1 "$tmp")
    if echo "$first" | grep -qE 'proxies:|proxy-groups:|mixed-port:'; then
        sed -n '/^proxies:/,/^proxy-groups:/p' "$tmp" | grep 'name:'
    else
        local decoded='/tmp/sub_dec.txt'
        base64 -d "$tmp" > "$decoded" 2>/dev/null || cp "$tmp" "$decoded"
        while IFS= read -r line; do
            case "$line" in
                ss://*) _parse_ss "$line" ;;
                trojan://*) _parse_trojan "$line" ;;
                anytls://*) _parse_anytls "$line" ;;
            esac
        done < "$decoded"
        rm -f "$decoded"
    fi
    rm -f "$tmp"
}

_parse_ss() {
    local line="$1"
    line="${line#ss://}"
    local name=$(echo "$line" | sed -n 's/.*#//p' | tr -d '\r')
    local rest="${line%%#*}"
    local decoded=$(echo -n "$rest" | base64 -d 2>/dev/null || echo "$rest")
    local method=$(echo "$decoded" | sed -n 's/^\([^:]*\):.*/\1/p')
    local passwd=$(echo "$decoded" | sed -n 's/^[^:]*:\([^@]*\)@.*/\1/p')
    local server_port=$(echo "$decoded" | sed -n 's/.*@//p')
    local server=$(echo "$server_port" | sed -n 's/:\([0-9]*\)$//p')
    local port=$(echo "$server_port" | sed -n 's/.*://p')
    [ -z "$method" ] && method="2022-blake3-aes-128-gcm"
    [ -z "$name" ] && name="SS-$port"
    echo "  - {name: \"$name\", server: $server, port: $port, type: ss, cipher: $method, password: \"$passwd\", udp: true}"
}

_parse_trojan() {
    local line="$1"
    line="${line#trojan://}"
    local name=$(echo "$line" | sed -n 's/.*#//p' | tr -d '\r')
    local rest="${line%%#*}"
    local passwd=$(echo "$rest" | sed -n 's/^\([^@]*\)@.*/\1/p')
    local server_port=$(echo "$rest" | sed -n 's/.*@//p' | sed 's/?.*//')
    local server=$(echo "$server_port" | sed -n 's/:\([0-9]*\)$//p')
    local port=$(echo "$server_port" | sed -n 's/.*://p')
    [ -z "$name" ] && name="Trojan-$port"
    echo "  - {name: \"$name\", server: $server, port: $port, type: trojan, password: \"$passwd\", sni: www.baidu.com, skip-cert-verify: true, udp: true}"
}

_parse_anytls() {
    local line="$1"
    line="${line#anytls://}"
    local name=$(echo "$line" | sed -n 's/.*#//p' | tr -d '\r')
    local rest="${line%%#*}"
    local passwd=$(echo "$rest" | sed -n 's/^\([^@]*\)@.*/\1/p')
    local server_port=$(echo "$rest" | sed -n 's/.*@//p' | sed 's/?.*//')
    local server=$(echo "$server_port" | sed -n 's/:\([0-9]*\)$//p')
    local port=$(echo "$server_port" | sed -n 's/.*://p')
    [ -z "$name" ] && name="AnyTLS-$port"
    echo "  - {name: \"$name\", server: $server, port: $port, type: anytls, password: \"$passwd\", client-fingerprint: chrome, sni: www.baidu.com, skip-cert-verify: true, alpn: [h2, http/1.1], udp: true}"
}

_sub_single_input() {
    printf "  ${Y}节点链接: ${N}"
    read url
    [ -z "$url" ] && return
    _sub_single "$url"
}

_sub_single() {
    local url="$1"
    local line=""
    case "$url" in
        ss://*) line=$(_parse_ss "$url") ;;
        trojan://*) line=$(_parse_trojan "$url") ;;
        anytls://*) line=$(_parse_anytls "$url") ;;
        *) pl "${R}  不支持${N}"; return ;;
    esac
    [ -z "$line" ] && { pl "${R}  解析失败${N}"; return; }
    pl "  $line"
    pl "${Y}  添加? (y/N)${N}"
    printf '  > '
    read confirm
    case "$confirm" in [Yy]*) ;; *) return ;; esac
    local bakfile="$CONFIG.bak.single.$(date +%s)"
    cp "$CONFIG" "$bakfile" 2>/dev/null
    sed -i "/^proxy-groups:/i\  $line" "$CONFIG" 2>/dev/null
    _reload_config && pl "${G}  已添加${N}" || { pl "${R}  FAIL${N}"; cp "$bakfile" "$CONFIG" 2>/dev/null; }
}

_sub_del() {
    [ ! -s "$_subfile" ] && { pl "${R}  无订阅${N}"; return; }
    _sub_list
    printf '  输入序号删除 (0=取消): '
    read choice
    [ "$choice" = "0" ] || [ -z "$choice" ] && return
    # 只接受纯数字（防 sed 行地址注入，如 "1d" "1,2d"）
    case "$choice" in
        ''|*[!0-9]*) pl "${R}  无效序号${N}"; return 1 ;;
    esac
    local total=$(grep -cE '.' "$_subfile")
    if [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ] 2>/dev/null; then
        pl "${R}  序号超出范围 (1-$total)${N}"; return 1
    fi
    sed -i "${choice}d" "$_subfile" 2>/dev/null
    pl "${G}  已删除${N}"
}

_do_sub_import() {
    if [ -n "$1" ]; then
        case "$1" in
            http://*|https://*) _sub_update_one "$1" ;;
            ss://*|trojan://*|anytls://*) _sub_single "$1" ;;
            *) _sub_menu ;;
        esac
    else
        _sub_menu
    fi
}



# ============================================================
# 订阅自动更新 (cc sub-auto)
# ============================================================
_sub_auto_update() {
    local interval="${1:-}"
    local subfile='/etc/clash-rs/subscriptions.list'

    # 显示当前设置
    _show_sub_auto() {
        local crontab_out=$(crontab -l 2>/dev/null)
        local sub_cron=$(echo "$crontab_out" | grep 'sub-update' | head -1)
        if [ -n "$sub_cron" ]; then
            local sched=$(echo "$sub_cron" | awk '{print $1, $2}')
            if echo "$interval" | grep -qE '^[0-9]{1,2}:[0-9]{2}$'; then
                echo "当前: 每天 ${interval} 自动更新"
            elif echo "$sched" | grep -qE '^[0-9]+ [0-9]+ \* \* \*'; then
                echo "当前: 每天 $sched 自动更新"
            else
                echo "当前: $sched (每 $interval 小时)"
            fi
        else
            echo "当前: 未启用自动更新"
        fi
    }

    if [ -n "$interval" ]; then
        # 直接设置
        if [ "$interval" = "0" ] || [ "$interval" = "off" ]; then
            # 关闭自动更新
            _crontab_out=$(crontab -l 2>/dev/null)
            [ -n "$_crontab_out" ] && echo "$_crontab_out" | grep -v 'sub-update' | crontab -
            pl "${G}已关闭订阅自动更新${N}"
            return
        fi
        # 支持 "HH:MM" 格式：每天指定时刻
        if echo "$interval" | grep -qE '^[0-9]{1,2}:[0-9]{2}$'; then
            local _hh=$(echo "$interval" | cut -d: -f1)
            local _mm=$(echo "$interval" | cut -d: -f2)
            # 校验范围
            if [ "$_hh" -ge 0 ] 2>/dev/null && [ "$_hh" -le 23 ] 2>/dev/null && \
               [ "$_mm" -ge 0 ] 2>/dev/null && [ "$_mm" -le 59 ] 2>/dev/null; then
                local sched="$_mm $_hh * * *"
            else
                pl "${R}  时间无效 (小时0-23, 分钟0-59)${N}"
                return
            fi
        else
            # 设置间隔（小时） - 5字段: 分 时 日 月 周
            local sched="0 */$interval * * *"
            # 如果是 24 的因数，用每天
            if [ "$interval" = "24" ]; then sched="0 0 * * *"
            elif [ "$interval" = "12" ]; then sched="0 */12 * * *"
            elif [ "$interval" = "6" ]; then sched="0 */6 * * *"
            elif [ "$interval" = "4" ]; then sched="0 */4 * * *"
            elif [ "$interval" = "2" ]; then sched="0 */2 * * *"
            elif [ "$interval" = "1" ]; then sched="0 * * * *"
            fi
        fi
        # 先删旧的 sub-update 行（保留其他任务）
        _crontab_out=$(crontab -l 2>/dev/null)
        if [ -n "$_crontab_out" ]; then
            echo "$_crontab_out" | grep -v 'sub-update' > /tmp/ct.new 2>/dev/null
        else
            : > /tmp/ct.new
        fi
        # 追加新的 sub-update 行（不能整体替换 crontab！）
        echo "$sched /etc/clash-rs/cc.sh sub-update >/dev/null 2>&1" >> /tmp/ct.new
        crontab /tmp/ct.new 2>/dev/null
        rm -f /tmp/ct.new
        if echo "$interval" | grep -qE '^[0-9]{1,2}:[0-9]{2}$'; then
            pl "${G}已设置: 每天 ${interval} 自动更新订阅${N}"
        else
            pl "${G}已设置: 每 $interval 小时自动更新订阅${N}"
        fi
        return
    fi

    # 交互菜单
    while true; do
        printf '\n'
        line
        pl "${C}  订阅自动更新${N}"
        line
        _show_sub_auto
        pl "  ${W}1${N}. 每 1 小时"
        pl "  ${W}2${N}. 每 2 小时"
        pl "  ${W}3${N}. 每 4 小时"
        pl "  ${W}4${N}. 每 6 小时"
        pl "  ${W}5${N}. 每 12 小时"
        pl "  ${W}6${N}. 每天 0:00"
        pl "  ${W}7${N}. 自定义 (输入任意小时数)"
        pl "  ${W}8${N}. 指定时间 (每天 HH:MM, 如 03:30)"
        pl "  ${W}0${N}. 关闭自动更新"
        line
        printf '\n  选择: '
        read sm_choice
        case "$sm_choice" in
            1) _sub_auto_update 1; break ;;
            2) _sub_auto_update 2; break ;;
            3) _sub_auto_update 4; break ;;
            4) _sub_auto_update 6; break ;;
            5) _sub_auto_update 12; break ;;
            6) _sub_auto_update 24; break ;;
            7)
                printf "  输入间隔小时数 (如 3=每3小时, 8=每8小时): "
                read custom_h
                [ -n "$custom_h" ] && [ "$custom_h" -ge 1 ] 2>/dev/null && _sub_auto_update $custom_h && break
                pl "${R}  无效${N}"
                ;;
            8)
                printf "  输入每天更新时间 (HH:MM, 如 03:30): "
                read custom_time
                [ -n "$custom_time" ] && echo "$custom_time" | grep -qE '^[0-9]{1,2}:[0-9]{2}$' && _sub_auto_update "$custom_time" && break
                pl "${R}  格式错误, 例如 03:30 或 14:05${N}"
                ;;
            0) _sub_auto_update off; break ;;
            *) pl "${R}  无效${N}" ;;
        esac
    done
}

_sub_update_all() {
    local subfile='/etc/clash-rs/subscriptions.list'
    [ ! -s "$subfile" ] && { pl "${R}  无订阅${N}"; return 1; }
    pl "${C}  更新所有订阅...${N}"
    local total=0
    local allnodes='/tmp/sub_all_nodes.txt'
    > "$allnodes"
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        local nodes=$(_sub_download_one "$url")
        if [ -n "$nodes" ]; then
            echo "$nodes" >> "$allnodes"
            local n=$(echo "$nodes" | grep -c 'name:')
            total=$((total+n))
            pl "  ${G}OK${N} $(echo "$url" | cut -c1-50)... (${n}节点)"
        else
            pl "  ${R}FAIL${N} $(echo "$url" | cut -c1-50)..."
        fi
    done < "$subfile"
    if [ "$total" -eq 0 ]; then
        pl "${R}  无有效节点${N}"
        rm -f "$allnodes"
        return 1
    fi
    pl "${Y}  共 $total 个节点, 合并到 config...${N}"

    # 备份
    cp "$CONFIG" "$CONFIG.bak.sub.$(date +%s)" 2>/dev/null
    # 清理旧备份，只保留最近 3 个（防止 sub-update 每日累积占满磁盘）
    ls -t $CONFIG.bak.sub.* 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null

    # 解析节点（URL解码+过滤）
    local node_names=""
    local real_nodes=""
    while IFS= read -r line; do
        echo "$line" | grep -qE 'name:.*(剩余|到期|重置|套餐|%E5%89%A9|%E5%88%B0|%E9%87%8D|%E5%A5%97)' && continue
        local name=$(echo "$line" | sed -n 's/.*name: "\([^"]*\)".*/\1/p')
        [ -z "$name" ] && continue
        local decoded=$(printf "%b" "$(echo "$name" | sed 's/%/\\\\x/g')" 2>/dev/null)
        [ -z "$decoded" ] && decoded="$name"
        echo "$decoded" | grep -qE '剩余|到期|重置|套餐|GB|天' && continue
        local new_line=$(name="$name" decoded="$decoded" awk 'BEGIN{a="name: \"" ENVIRON["name"] "\""; b="name: \"" ENVIRON["decoded"] "\""} {i=index($0,a); if(i>0){print substr($0,1,i-1) b substr($0,i+length(a))} else print}' 2>/dev/null)
        [ -z "$new_line" ] && new_line="$line"
        # 去重：节点名已在列表则跳过（防止 duplicated proxy name 崩溃）
        echo "$node_names" | grep -Fqx "$decoded" && continue
        node_names="$node_names
$decoded"
        real_nodes="$real_nodes
$new_line"
    done < "$allnodes"

    # 从旧 config 提取 header 和 rules
    local header=$(sed -n '1,/^proxies:/p' "$CONFIG" | sed '$d')
    local rules=$(sed -n '/^rules:/,$p' "$CONFIG")

    # 生成新 config
    {
        echo "$header"
        echo ""
        echo "proxies:"
        echo "$real_nodes" | grep -v '^$'
        echo ""
        echo "proxy-groups:"
        echo "  - name: PROXY"
        echo "    type: select"
        echo "    proxies:"
        echo "      - AUTO"
        echo "      - DIRECT"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do
            echo "      - \"$n\""
        done
        echo ""
        echo "  - name: AUTO"
        echo "    type: url-test"
        echo "    url: http://cp.cloudflare.com/generate_204"
        echo "    interval: 600"
        echo "    tolerance: 100"
        echo "    timeout: 5"
        echo "    proxies:"
        echo "$node_names" | grep -v '^$' | while IFS= read -r n; do
            echo "      - \"$n\""
        done
        echo ""
        echo "$rules"
    } > "$CONFIG.tmp"

    # 先 mv 再 reload（避免 reload 旧 config）
    mv "$CONFIG.tmp" "$CONFIG" 2>/dev/null
    pl "${G}  更新成功: $total 个节点, 重启 clash-rs 生效${N}"
    /etc/init.d/clash-rs restart >/dev/null 2>&1 &
    rm -f "$allnodes"
}


case "$1" in
    start)    do_start ;;
    stop)     do_stop ;;
    restart)  do_restart ;;
    status)   do_status ;;
    switch)   do_switch "$2" "$3" "$4" ;;
    autoswitch) do_switch --auto --group AUTO ;;
    test)     do_test "$2" ;;
    node)     do_node "$2" "$3" ;;
    monitor)  do_monitor ;;
    log)      do_log ;;
    mem)      do_flush ;;
    flush)    do_flush ;;
    nettest)  do_nettest ;;
    top)      do_top ;;
    speed)    do_speed ;;
    conn)     do_conn ;;
    settings) show_settings ;;
    doctor)   do_doctor ;;
    sysinfo)  do_sysinfo ;;
    nss)      do_nss ;;
    backup)   do_backup "$2" "$3" ;;
    binver)   do_binver ;;
    binbak)   do_binbak "$2" "$3" ;;
    tune)     do_tune "$2" "$3" ;;
    apiconf)  do_apiconf ;;
    patch)    do_patch "$2" "$3" ;;
    conns)
        case "$2" in
            kill) do_conns_kill "$3" ;;
            *) pl "${R}  用法: cc conns kill <id|all>${N}" ;;
        esac
        ;;
    rules)    do_rules "$2" ;;
    dns-query) do_dns_query "$2" "$3" ;;
    flows)    do_flows "$2" ;;
    provider) do_provider "$2" "$3" ;;
    tun)      do_tun ;;
    dns-mode) do_dns_mode "$2" ;;
    fullbackup) _full_backup ;;
    fullbackup-all) _full_backup_all ;;
    fullrestore) _full_restore "$2" ;;
    start-lastgood) _start_lastgood ;;
    sub) _do_sub_import "$1" ;;
    sub-update) _sub_update_all ;;
    sub-auto) _sub_auto_update "$2" ;;
    dns)
        # cc dns 进入DNS子菜单; cc dns-query <domain> 是DNS测试
        if [ -z "$2" ]; then do_dns_conf
        else
            pl "${R}  用法: cc dns (进入子菜单) 或 cc dns-query <domain> (DNS测试)${N}"
        fi
        ;;
    profile)  do_profile ;;
    clashconf) do_clash_conf ;;
    tolerance) /usr/bin/tolerance-config.sh $2 ;;
    autogroup) do_autogroup ;;
    version|--version|-v) show_version ;;
    help|--help|-h)
        pl "${W}cc - clash-rs 管理命令 (v${CC_VERSION})${N}"
        pl ""
        pl "  ${C}=== 服务管理 ===${N}"
        pl "  cc           进入交互式主菜单 (集成所有功能)"
        pl "  cc start     启动 clash-rs 服务 (含前置检查/加载配置)"
        pl "  cc stop      停止 clash-rs 服务 (清理iptables/路由规则)"
        pl "  cc restart   重启服务 (先stop再start, 等待端口释放)"
        pl "  cc status    查看运行状态 (PID/内存/运行时长/当前节点/AUTO延迟)"
        pl ""
        pl "  ${C}=== 节点与连接 ===${N}"
        pl "  cc switch    交互式切换 PROXY 组当前节点 (列出节点+延迟)"
        pl "  cc switch --auto   自动选择最快节点 (按延迟排序取最优)"
        pl "  cc autoswitch  自动测速并切换AUTO组到最快节点 (TCP测速支持SS2022, 供crontab)"
        pl "  cc test      并发测试 PROXY 组所有节点延迟 (5秒超时)"
        pl "  cc test auto 测试 AUTO 组延迟并排序 (评估自动选节点效果)"
        pl "  cc node list 列出所有节点 (PROXY组+AUTO组, 含类型/服务器)"
        pl "  cc node add  添加节点 (粘贴YAML节点定义, 自动写入配置)"
        pl "  cc node del  删除节点 (交互选择, 自动清理引用)"
        pl "  cc conn      查看活跃连接 TOP20 (含上下行流量/规则/节点)"
        pl "  cc conns kill <id|all>   关闭指定ID连接或全部连接 (强制断流)"
        pl "  cc flows [N] 流量流向聚合 TOP N (按目标主机统计上下行, 默认15)"
        pl "  cc rules [N] 查看路由规则 (显示前N条, 默认50, 含类型/载体/出口)"
        pl "  cc provider [list|update <name|all>]  代理集/规则集管理 (更新订阅)"
        pl ""
        pl "  ${C}=== 配置热修改 (无需重启) ===${N}"
        pl "  cc apiconf   查看运行时配置 (GET /configs, 显示端口/模式/日志等)"
        pl "  cc patch <field> <value>   热改顶层字段并持久化"
        pl "      支持: port/socks-port/redir-port/tproxy-port/mixed-port"
        pl "            mode(rule/global/direct) log-level ipv6 allow-lan bind-address"
        pl "  cc tun       TUN配置子菜单 (enable/device/gateway/mtu/dns-hijack)"
        pl "      TUN模式接管全局流量, 需内核tun模块支持"
        pl "  cc dns       DNS配置子菜单 (enable/ipv6/enhanced-mode/listen UDP+TCP)"
        pl "      fake-ip模式可提升解析速度, listen需同时改UDP和TCP"
        pl "  cc profile   Profile持久化子菜单 (store-selected/fake-ip/smart-stats)"
        pl "      控制重启后是否保留节点选择/fake-ip映射/smart统计"
        pl "  cc clashconf clash-rs核心配置子菜单 (顶层字段)"
        pl "      覆盖: external-controller/secret/external-ui/external-ui-url"
        pl "            cors-allow-origins/mmdb/geosite/geosite-download-url"
        pl "            routing-mark/interface/keep-alive-interval"
        pl "  cc settings  完整设置菜单 (开机自启/内存/看门狗/端口/IPv6/experimental)"
        pl ""
        pl "  ${C}=== 诊断与监控 ===${N}"
        pl "  cc monitor   实时监控 (CPU/内存/NSS/温度, 2秒刷新, Ctrl+C退出)"
        pl "  cc log       查看最近日志 (默认100行, 含clash-rs运行信息)"
        pl "  cc mem       清理内存缓存 (drop_caches, 释放已被占用的缓存页)"
        pl "  cc nettest   网络连通性测试 (DNS/直连/代理/国内/国外分项检测)"
        pl "  cc top       进程资源详情 (CPU/FD数/OOM风险/线程, 排查资源泄漏)"
        pl "  cc speed     网速测试 (直连 vs 代理对比, 下载测速)"
        pl "  cc dns-query <domain> [type]  DNS解析测试 (走clash-rs内置DNS)"
        pl "      type: A/AAAA/CNAME/MX/TXT/NS/SOA, 默认A"
        pl "  cc doctor    一键诊断 (二进制/配置/端口/DNS/iptables全面检查)"
        pl "  cc sysinfo   系统信息 (CPU/内存/磁盘/网络接口/NSS状态)"
        pl "  cc nss       NSS硬件加速状态 (驱动版本/CPU亲和/包统计/ECM)"
        pl ""
        pl "  ${C}=== 备份与调优 ===${N}"
        pl "  cc backup    立即备份当前 config.yaml"
        pl "  cc backup list     查看配置备份列表 (按时间排序)"
        pl "  cc backup restore [编号]   从备份恢复配置 (自动重载)"
        pl "  cc binver    查看二进制版本与已备份版本 (对比可回滚版本)"
        pl "  cc binbak    立即备份当前 clash-rs 二进制"
        pl "  cc binbak list     查看二进制备份列表"
        pl "  cc binbak restore [编号]   从二进制备份恢复 (升级失败时回退)"
        pl "  cc tune      高级调优子菜单 (交互式)"
        pl "  cc tune <sub> <val>  直接设置单项"
        pl "      sub: buffer/conntrack/cpu/priority/mtu/mem/irq"
        pl "      例: cc tune mem aggressive  (8MB激进, 最大化可用RAM)"
        pl "          cc tune buffer aggressive / cc tune cpu performance"
        pl "      预设: aggressive(激进) / balanced(平衡) / conservative(保守)"
        pl "      持久化到 /etc/sysctl.d/99-clash-rs.conf + uci/rc.local"
        pl ""
        pl "  cc version   版本与信息 (脚本版本/二进制/配置/运行状态/系统信息)"
        pl ""
        pl "  ${Y}提示: 大部分命令支持 cc <命令> 直接执行, 或 cc 进入菜单交互${N}"
        ;;

    *)        show_menu ;;
esac
