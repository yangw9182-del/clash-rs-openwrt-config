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
| 国内域名白名单 | `scripts/geosite-cn-update` + `scripts/fakeip-cn-auto` | **社区列表条件下载 + 自学习补漏**，零重启 |

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
| `geosite-cn-update` | 每3天6:10 | 社区白名单条件下载(零重启, `cc sub-sync auto` 生成) |
| `fakeip-cn-auto sync` | 每3天6:10 | 自学习收集(零重启, `cc sub-sync auto` 生成) |

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
cc sub-sync auto         # 国内白名单自动更新(探测重启事件同频, 零重启)
cc sub-sync status       # 查看双源白名单/时间策略状态
```

完整命令手册见 **[docs/cc命令手册.md](docs/cc命令手册.md)**，排障见 **[docs/部署与排障手册.md](docs/部署与排障手册.md)**。

---

## ⚙️ 核心机制说明

### 国内域名双源白名单（社区列表 + 自学习，零重启）✨

**为什么**：大陆站点域名被污染时，让它进 `fake-ip-filter` → DNS 返回真实 IP → iptables `cn_ip` 直连，流量**完全不经过代理进程** = 最快、最稳。内核用 trie 按域名 label 分段匹配，加多少条都不慢（实测 5000+ 条 RSS 与不注入持平，内存成本 ≈ 0）。

**双源架构**（`cc sub-sync` 管理）：

```
主源 = 社区 geosite 列表（别人维护，别人更新我们同步）
  config/fakeip-cn-geosite.list（v2fly GEOLOCATION-CN 主域 ~4000 条 +.域名）
  /usr/bin/geosite-cn-update：curl -z 条件下载(If-Modified-Since) + md5 双保险
    → 检测到没更新就不下载 → 缺失插入 config → 零重启

补充 = 自学习（可选，默认开）
  /usr/bin/fakeip-cn-auto sync：从 clash connections 动态收集你实际访问的国内域名
    → 独立存 /etc/clash-rs/fakeip-cn.list → apply 插入 config → 零重启
```

**社区更新永不丢失自学习**：
- `geosite-cn-update` 只做**缺失插入**，**从不删除、从不覆盖**已有条目（包括自学习加进去的）
- 自学习数据独立存在 `/etc/clash-rs/fakeip-cn.list`，社区脚本完全不碰
- 即使社区上游删掉某条，本机已注入的也保留（宁可多留，不误伤真实用户访问）
- 两个脚本各自单实例锁，互不干扰

#### 时间策略（三种模式）

| 模式 | 命令 | 行为 |
|------|------|------|
| **自动（推荐）** | `cc sub-sync auto [LEAD]` | 扫描 crontab 找「会重启」的事件（reboot / sub-update / clash-rs restart），更新时间 = 事件时刻 − 提前量（默认 10 分钟），**与事件同频**（沿用其日/月/周字段）；无重启事件时退化为每日条件检查（`cc sub-sync auto-daily off` 可关） |
| **自定义** | `cc sub-sync on HH:MM` | 固定每天 HH:MM 更新，避开重启时间 |
| **关闭** | `cc sub-sync off` | 移除定时，仅开机检查 + 手动 `cc sub-sync run` |

**自动模式的核心理念：靠近重启，但不主动重启。**

```
例（crontab.example 默认）：
  20 6 */3 * * ... reboot        ← 每3天 6:20 重启
  25 6 */3 * * ... sub-update    ← 每3天 6:25 订阅更新(内容变化会重启 clash-rs)

cc sub-sync auto 10  →  探测到最近生效事件(优先选生效最频繁者) 6:20(reboot)
  → 更新时间 = 6:20 − 10min = 6:10，cron: 10 6 */3 * * /usr/bin/geosite-cn-update
  → 6:10 拉最新社区列表（条件下载，没更新不下载，零流量）
  → 6:20 重启，init.d 顺带应用新白名单 —— 全程零主动重启
```

**为什么零重启也安全**：`geosite-cn-update` 是条件下载，没更新不下载；每次开机 init.d 也会跑一次条件检查兜底。更新写入 config 后，下一次任意重启/订阅更新都会顺带生效，不会漏。

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