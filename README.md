# ClashRS OpenWrt 完整部署配置

> 一套经过真实路由器长期运行的 **clash-rs 稳定部署方案**：透明代理 + 自适应节点选择 + DNS 防重置 + OOM 保护 + 自愈监控。
>
> 配套内核：[yangw9182-del/clash-rs](https://github.com/yangw9182-del/clash-rs)（20 处稳定性修复的 fork）。

**实测设备**：DSG-AX3000（IPQ5018, 128MB RAM, OpenWrt 19.07），连续运行 30+ 天无崩溃。

---

## ✨ 功能一览

| 模块 | 文件 | 作用 |
|------|------|------|
| 服务管理 | `init/clash-rs` | 开机启动 clash-rs + watchdog，内存限制，DNS 上下游接管 |
| 内存看门狗 | `scripts/clash-watchdog` | 监控 clash-rs 内存/存活，崩溃自动恢复，移除/还原 iptables 规则 |
| 自适应降级 | `scripts/tune-tolerance.sh` | 节点长期不切换自动调低 tolerance，切换后恢复（**零重启** PATCH 改配置）|
| 交互配置 | `scripts/tolerance-config.sh` | 傻瓜式配置降级参数（`cc tolerance` 或直接执行）|
| DNS 守卫 | `scripts/dns-guard` | 每10分钟确保 dnsmasq 上游=1053，顺带保持 dnsmasq OOM 保护 |
| 节点修复 | `scripts/fix-nodes` | 探测节点 IP 连通性，服务器换 IP 时自动替换 |
| 日志轮转 | `scripts/clash-logrotate` | 5 个日志文件上限 100KB，超过自动截断保留 50KB |
| 内核调优 | `config/sysctl.conf` | conntrack 262144、min_free=8MB、IPv6 禁用等 |
| 配置模板 | `config/config.yaml.example` | 脱敏配置模板（含 fake-ip-filter 1022 条国内域名）|

---

## 🚀 快速部署（OpenWrt）

### 0. 前提
- OpenWrt 路由器，已装 clash-rs 内核（见配套 fork 的编译说明）
- SSH 能连上路由器

### 1. 上传内核
```bash
# 本地执行，把编译好的 clash-rs 传到路由器
scp clash-rs root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "mv /tmp/clash-rs /etc/clash-rs/clash-rs && chmod 755 /etc/clash-rs/clash-rs"
```

### 2. 上传配置与脚本
```bash
# 本地
scp config/config.yaml.example root@192.168.1.1:/etc/clash-rs/config.yaml
scp config/tolerance.conf root@192.168.1.1:/etc/clash-rs/tolerance.conf
scp config/sysctl.conf root@192.168.1.1:/etc/sysctl.conf
scp scripts/* root@192.168.1.1:/usr/bin/
scp init/clash-rs root@192.168.1.1:/etc/init.d/clash-rs
scp init/local root@192.168.1.1:/etc/init.d/local
scp init/rc.local root@192.168.1.1:/etc/rc.local
```

### 3. 设置权限与符号链接
```bash
ssh root@192.168.1.1
chmod 755 /etc/init.d/clash-rs /etc/init.d/local /etc/rc.local
chmod 755 /usr/bin/tune-tolerance.sh /usr/bin/tolerance-config.sh /usr/bin/dns-guard /usr/bin/fix-nodes /usr/bin/clash-logrotate
chmod 755 /etc/clash-rs/*.sh 2>/dev/null
# 关键: 让 init.d 生效
ln -sf /etc/init.d/clash-rs /etc/rc.d/S99clash-rs
ln -sf /etc/init.d/local /etc/rc.d/S95local
```

### 4. 配置 crontab
```bash
ssh root@192.168.1.1
crontab -l > /tmp/ct.bak
cat >> /tmp/ct.bak << 'EOF'
*/10 * * * * /usr/bin/clash-tolerance.sh >/dev/null 2>&1   # 自适应降级(与测速同频)
*/10 * * * * /usr/bin/clash-logrotate 2>/dev/null          # 日志轮转
*/10 * * * * /usr/bin/dns-guard 2>/dev/null                # DNS 守卫
*/30 * * * * flock -n /tmp/fix-nodes.lock -c "/usr/bin/fix-nodes >/dev/null 2>&1"
0 * * * * echo 1 > /proc/sys/vm/drop_caches 2>/dev/null
EOF
crontab /tmp/ct.bak
```

> ⚠️ 我把本仓库 crontab.example 的路径改成了你的实际路径（`tune-tolerance.sh` 而非 `clash-tolerance.sh`），按实际文件名对齐。部署时可参考 `config/crontab.example` 对照。

### 5. 修改配置文件
```bash
# config.yaml 的 secret 和节点需换成你自己的（节点可用订阅工具更新）
vi /etc/clash-rs/config.yaml
```

### 6. 启动
```bash
/etc/init.d/clash-rs start
# 验证
ps | grep clash-rs            # 进程在
netstat -ulnp | grep 1053     # DNS 监听
curl -s http://127.0.0.1:9090/version   # API
```

---

## ⚙️ 核心机制说明

### 自适应 tolerance 降级（`tune-tolerance.sh`）
节点每 10 分钟测速一次。如果**连续 N 次都不切换**（说明当前节点"刚好够用"但可能不是最优），自动调低 tolerance 让 AUTO 组更敏感：

```
初始: tolerance=100ms (持续10次/100分钟不切)
  ↓ 降级1: tolerance=80ms (再持续8次/80分钟)
  ↓ 降级2: tolerance=60ms (最低, 再持续5次/50分钟)
  ↓ 任意时刻切换了 → 立即恢复 100ms
```

- 改配置用 **PATCH API `{"proxy-groups":{"AUTO":{"tolerance":N}}}`**，零重启不断网
- 全部参数可在 `tolerance.conf` 或 `cc tolerance` 交互菜单修改

### DNS 防重置（`dns-guard`）
某些固件会把 dnsmasq 上游重置成 119/223 直连。`dns-guard` 每 10 分钟检查，发现不是 `127.0.0.1#1053` 就改回，并保持 dnsmasq 的 `oom_score_adj=-1000`。

### 节点 IP 自愈（`fix-nodes`）
机场节点服务器会换 IP。`fix-nodes` 每 30 分钟探测各节点 TCP 连通性，发现失效就从 `known_ips` 候选池找替代 IP 写入配置。

### OOM 保护
- clash-rs / watchdog / netifd / dnsmasq 全部 `oom_score_adj=-1000`
- `vm.min_free_kbytes=8192`（释放 4MB 内存给应用）
- 内核无 swap，靠内存保护防止 OOM killer 杀关键进程

---

## 🔧 故障排查

| 症状 | 排查 |
|------|------|
| 核心开着没网 | `netstat -ulnp \| grep 1053` 是否被 clash 监听；`uci get dhcp.@dnsmasq[0].server` 是否 1053 |
| watchdog 反复重启 | `tail -50 /var/log/clash-watchdog.log`，看崩溃原因和 EMA_avail |
| 大陆网站卡 | 确认域名在 `fake-ip-filter`（真实解析→iptables cn_ip 直连）；`nslookup 域名 127.0.0.1` 应返回真实 IP |
| 节点切换太频繁 | 调高 `tolerance`（config.yaml AUTO 组）+ 检查 `tune-tolerance.log` 切换记录 |
| 日志膨胀 | `clash-logrotate` 设置 100KB 上限，确认 crontab 在跑 |

---

## 📄 License
随 fork 内核采用上游 license（GPLv3 兼容）。配置与脚本 MIT。

## 🙏 感谢
- [Watfaq/clash-rs](https://github.com/Watfaq/clash-rs)：上游内核
- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)：国内域名列表来源