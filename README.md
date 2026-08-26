# ClashRS OpenWrt 完整部署配置

> 一套经过真实路由器长期运行的 **clash-rs 稳定部署方案**：透明代理 + 自适应节点选择 + DNS 防重置 + OOM 保护 + 自愈监控 + 一体化管理工具（`cc`）。
>
> 配套内核（20 处稳定性修复）：[yangw9182-del/clash-rs](https://github.com/yangw9182-del/clash-rs)

**实测设备**：DSG-AX3000（IPQ5018, 256MB RAM, OpenWrt 19.07），连续运行 30+ 天无崩溃。

---

## ✨ 功能一览

| 模块 | 文件 | 作用 |
|------|------|------|
| **一体化管理工具** | `scripts/cc.sh` | 30+ 命令：服务/节点/调优/备份/诊断，详情看 [cc命令手册](docs/cc命令手册.md) |
| 服务管理 | `init/clash-rs` | 开机启动 + watchdog + 内存保护 + DNS 接管 |
| 二进制托管 | `scripts/clash-wrapper` | clash 二进制守护包装（崩溃自动拉起）|
| 内存看门狗 | `scripts/clash-watchdog` | 内存/存活监控，崩溃自动恢复 |
| 时区对齐 | `scripts/safe-ntp` | 定时校时（防日志时间漂移）|
| 自适应降级 | `scripts/tune-tolerance.sh` | 节点长期不切换自动调低 tolerance（**PATCH 零重启**）|
| 交互配置 | `scripts/tolerance-config.sh` | 傻瓜式配置降级参数 |
| DNS 守卫 | `scripts/dns-guard` | 确保 dnsmasq 上游=1053 + OOM 保护 |
| 节点修复 | `scripts/fix-nodes` | 探测节点 IP，服务器换 IP 自动替换 |
| 发送队列 | `scripts/fix-tx-queue` | 网卡 TX 队列调优 |
| 网卡调优 | `scripts/rps-tune.sh` / `scripts/netwifi-tune.sh` | RPS/XPS + WiFi 参数 |
| 自检修复 | `scripts/startup-heal.sh` | 开机自检修复 |
| 日志轮转 | `scripts/clash-logrotate` | 5 个日志上限 100KB |
| 内核调优 | `config/sysctl.conf` | conntrack/min_free/IPv6 禁用 |
| 配置模板 | `config/config.yaml.example` | 脱敏模板（fake-ip-filter 1022 条国内域名）|

---

## 🚀 快速部署（OpenWrt）

### 0. 前提
- OpenWrt 路由器（256MB+ 内存）
- clash-rs 内核[已编译](https://github.com/yangw9182-del/clash-rs)好

### 1. 上传文件（电脑到路由器）

```bash
# 内核
scp clash-rs root@192.168.1.1:/etc/clash-rs/clash-rs

# 配置
scp config/config.yaml.example root@192.168.1.1:/etc/clash-rs/config.yaml
scp config/tolerance.conf   root@192.168.1.1:/etc/clash-rs/tolerance.conf
scp config/sysctl.conf      root@192.168.1.1:/etc/sysctl.conf

# 脚本(全部, cc.sh/rps/netwifi/startup-heal 放 /etc/clash-rs/, 其余放 /usr/bin/)
scp scripts/cc.sh scripts/rps-tune.sh scripts/netwifi-tune.sh scripts/startup-heal.sh root@192.168.1.1:/etc/clash-rs/
scp scripts/*.sh scripts/clash-* scripts/dns-guard scripts/fix-* scripts/safe-ntp root@192.168.1.1:/usr/bin/

# init 脚本
scp init/clash-rs root@192.168.1.1:/etc/init.d/clash-rs
scp init/local    root@192.168.1.1:/etc/init.d/local
scp init/rc.local root@192.168.1.1:/etc/rc.local
```

### 2. 设置权限

```bash
chmod 755 /etc/init.d/clash-rs /etc/init.d/local /etc/rc.local
chmod 755 /etc/clash-rs/*.sh /usr/bin/cc.sh /usr/bin/*.sh
ln -sf /etc/init.d/clash-rs /etc/rc.d/S99clash-rs
ln -sf /etc/init.d/local    /etc/rc.d/S95local
```

### 3. 配置 crontab（自动任务）

```bash
crontab -l > /tmp/ct.bak
cat config/crontab.example >> /tmp/ct.bak
crontab /tmp/ct.bak
```

**crontab.example 中的任务说明**

| 任务 | 频率 | 作用 |
|------|------|------|
| `clash-logrotate` | 每10分钟 | 日志轮转(上限100KB) |
| `fix-tx-queue` | 每5分钟 | TX 队列调优 |
| `dns-guard` | 每10分钟 | DNS 上游防重置 |
| `tune-tolerance.sh` | 每10分钟 | 自适应降级(与测速同频) |
| `fix-nodes` | 每30分钟 | 节点 IP 自愈 |
| `safe-ntp` | 每10分钟 | 校时 |
| `drop_caches` | 每小时 | 内存回收 |
| `cc.sh sub-update` | 每3天 | 机场订阅更新 |
| `reboot` | 每3天6:20 | **可选**：定期重启清理内存（不需要可删行）|

### 4. 修改配置
```bash
vi /etc/clash-rs/config.yaml
# 1. secret: "CHANGE-ME" → 改成你的 API 密钥
# 2. proxies 段添加你的节点（建议用 cc node add 或 cc sub-update）
```

### 5. 启动
```bash
/etc/init.d/clash-rs start
cc status          # 应显示运行中
cc dns-query www.google.com   # 验证 DNS 链路
```

---

## 🎮 cc 命令快速上手

```bash
cc                  # 交互菜单
cc status           # 状态
cc switch <节点>     # 手动切换节点
cc autoswitch       # 切回 AUTO 自动选路
cc autogroup        # 配置 AUTO tolerance/interval
cc monitor          # 实时监控
cc doctor           # 一键诊断
cc backup           # 备份配置
cc patch tolerance 120   # 动态改 tolerance(零重启)
```

完整命令手册见 **[docs/cc命令手册.md](docs/cc命令手册.md)**，排障见 **[docs/部署与排障手册.md](docs/部署与排障手册.md)**。

---

## ⚙️ 核心机制说明

### 自适应 tolerance 降级（tune-tolerance.sh）
节点每 10 分钟测速。连续 N 次不切换 → 自动调低 tolerance 让 AUTO 更敏感：

```
初始: tolerance=100ms (持续10次/100分钟不切)
  ↓ 降级1: 80ms (再持续8次/80分钟)
  ↓ 降级2: 60ms (最低, 再持续5次/50分钟)
  ↓ 任意切换 → 恢复 100ms
```

改配置用 PATCH API，**零重启不断网**。参数在 `tolerance.conf` 或 `cc tolerance` 修改。

### DNS 防重置（dns-guard）
某些固件把 dnsmasq 上游重置成 119/223 直连。`dns-guard` 每 10 分钟检查并改回 `127.0.0.1#1053`，同时保持 dnsmasq `oom_score_adj=-1000`。

### 节点 IP 自愈（fix-nodes）
机场服务器换 IP 时自动从候选池替换，无需人工。

### OOM 保护
clash-rs / watchdog / netifd / dnsmasq 全部 `oom_score_adj=-1000`；`vm.min_free_kbytes=8192` 释放 4MB 给应用。

---

## 🔧 故障排查

| 症状 | 排查 |
|------|------|
| 核心开着没网 | `cc dns-query www.baidu.com`；`uci get dhcp.@dnsmasq[0].server` 是否 1053 |
| 大陆站卡 | 域名是否在 fake-ip-filter（`cc dns-query` 看是否返回真实IP）|
| 切换频繁 | `cat /var/log/tune-tolerance.log` 看切换记录；`cc autogroup` 调 tolerance |
| watchdog 反复重启 | `tail -50 /var/log/clash-watchdog.log` |
| 节点全死 | `cc monitor` 看延迟；`cc sub-update` 更新订阅 |

---

## 📄 License
- 配置与脚本：MIT
- 内核：随 [yangw9182-del/clash-rs](https://github.com/yangw9182-del/clash-rs)（上游 GPLv3）

## 🙏 上游项目
- [Watfaq/clash-rs](https://github.com/Watfaq/clash-rs)：clash-rs 内核上游
- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules)：fake-ip-filter 国内域名来源