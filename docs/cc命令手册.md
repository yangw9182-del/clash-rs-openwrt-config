# cc 命令手册（路由器管理工具）

`cc` 是本套配置自带的**一体化管理工具**（`/etc/clash-rs/cc.sh`），封装了 clash 服务管理、节点切换、内存调优、备份恢复、DNS 诊断等 30+ 个功能。

> 用法：`cc [命令]` 直接执行，或 `cc` 进入交互菜单。
> 所有命令在路由器 SSH 中执行。

---

## 一、服务管理（最常用）

| 命令 | 作用 |
|------|------|
| `cc start` | 启动 clash-rs |
| `cc stop` | 停止 clash-rs |
| `cc restart` | 重启（改配置后必须用它，**禁用 API 热重载**）|
| `cc status` | 查看运行状态 |

```bash
# 改完 config.yaml 后重启
cc restart

# 查看状态
cc status
```

---

## 二、节点切换

| 命令 | 作用 |
|------|------|
| `cc switch <节点>` | 手动切换指定节点 |
| `cc switch --auto` / `cc autoswitch` | 切到 AUTO 组自动模式（测速选最快）|
| `cc test` | 手动测速 |
| `cc autogroup` | **交互式配置 AUTO 组**（见下） |

### cc autogroup（重点）
管理 AUTO 组的三个关键参数：

```
tolerance: 切换容差(ms)
   当前节点延迟 > 最快节点延迟 + tolerance 才切换
   设 100 = 容忍 100ms 抖动，不频繁切换
interval:  测速间隔(秒), 默认 600 = 10分钟测一次
强制切换:  手动测速后立即强制切到最低延迟节点(忽略tolerance)
```

```bash
# 交互配置 AUTO 组
cc autogroup

# 手动测速并强制切换
cc test auto
```

---

## 三、节点管理与订阅

| 命令 | 作用 |
|------|------|
| `cc node list` | 查看已配置节点 |
| `cc node add <链接>` | 添加节点（ss:// trojan:// anytls://）|
| `cc node del <节点>` | 删除节点 |
| `cc sub-update` | 手动更新订阅（节点从机场更新）|
| `cc provider list` | 查看订阅 provider |
| `cc provider update <name\|all>` | 更新指定/全部 provider |

> ⚠️ 自动订阅更新默认每 3 天一次（crontab），可在 `cc profile` 中调整频率或关闭。

### 国内域名白名单（cc sub-sync）

**双源架构**：主源 = 社区 geosite 列表（`geosite-cn-update` 条件下载，别人维护我们同步）；补充 = 自学习（`fakeip-cn-auto` 从 clash connections 动态收集你实际访问的国内域名，可选默认开）。两者都**零重启**写入 `fake-ip-filter`，让国内域名 DNS 返回真实 IP 直连，**不经过代理进程** = 最快、最稳，内存成本 ≈ 0。

| 命令 | 作用 |
|------|------|
| `cc sub-sync run` | 立即更新（geosite 条件下载 + 自学习，零重启）|
| `cc sub-sync auto [LEAD]` | **自动时间（推荐）**：探测 crontab 中会重启的事件，更新时间 = 事件时刻 − 提前量（默认 10 分钟），与事件同频；无事件退化为每日 |
| `cc sub-sync auto-daily on\|off` | 无重启事件时是否退化为每日条件检查（默认开）|
| `cc sub-sync on [HH:MM]` | 自定义固定时间（默认 06:00）|
| `cc sub-sync off` | 关闭定时 |
| `cc sub-sync selflearn on\|off` | 自学习开关（默认开）|
| `cc sub-sync status` | 查看模式 / 依据事件 / 调度 / 条数 |

**自动模式详解（靠近重启，但不主动重启）**：

```
1. 扫描 crontab 找「会重启」的事件行：reboot / sub-update / clash-rs restart
2. 优先选「生效最频繁」的事件（日/月/周字段尽量多为 *），同频取最早时刻
3. 更新时间 = 事件时刻 − LEAD（默认10分钟），沿用事件的日/月/周字段（同频）
4. 更新零重启；由那次重启/订阅更新顺带应用，绝不主动重启
5. 无重启事件：退化为每日条件检查（`auto-daily off` 可关）
```

**社区更新永不丢失自学习**：`geosite-cn-update` 只做缺失插入、**从不删除/覆盖**；自学习独立存 `/etc/clash-rs/fakeip-cn.list`，两个脚本互不触碰。即使社区上游删掉某条，本机已注入的也保留。

```bash
# 自动模式（跟随 6:20 reboot，提前10分钟即 6:10 更新）
cc sub-sync auto
# 自定义每天 03:30
cc sub-sync on 03:30
# 查看状态
cc sub-sync status
```

---

## 四、性能调优

| 命令 | 作用 |
|------|------|
| `cc tune buffer` | TCP/UDP 缓冲区调优 |
| `cc tune conntrack` | conntrack 表 + hashsize |
| `cc tune cpu` | CPU 频率/调度 |
| `cc tune priority` | 进程优先级 |
| `cc tune mtu` | 网卡 MTU |
| `cc tune mem` | 内存（drop_caches）|
| `cc tune irq` | IRQ 绑定（RPS/XPS）|

```bash
# 查看当前全套调优参数
cc settings

# 一键诊断
cc doctor
```

---

## 五、监控与诊断

| 命令 | 作用 |
|------|------|
| `cc monitor` | 实时监控（节点延迟/连接数/内存）|
| `cc top` | 按流量 TOP 排序 |
| `cc speed` | 测速 |
| `cc conn` | 查看当前连接 |
| `cc conns kill <id\|all>` | 杀掉卡死连接 |
| `cc flows [N]` | 流量统计 TOP N（默认15）|
| `cc rules [N]` | 查看规则命中前 N 条（默认50）|
| `cc dns-query <域名> [type]` | 测试 DNS 解析 |
| `cc dns` | DNS 子菜单 |
| `cc nettest` | 网络连通性测试 |
| `cc sysinfo` | 系统信息（CPU/内存/负载）|
| `cc nss` | NAT 会话查看 |
| `cc log` | 查看 clash 日志 |

**排障示例：**
```bash
# 1. 域名解析不出来？直接查
cc dns-query www.douyin.com

# 2. 看规则是否命中
cc rules 20

# 3. 有连接卡死？杀掉
cc conns kill all

# 4. 看节点延迟分布
cc monitor
```

---

## 六、备份与恢复（重要！）

| 命令 | 作用 |
|------|------|
| `cc backup` | 创建配置备份（config.yaml/脚本/crontab 打包）|
| `cc backup list` | 列出历史备份 |
| `cc backup restore [编号\|文件名]` | 恢复指定备份 |
| `cc binbak backup` | 备份二进制 clash-rs |
| `cc binbak restore [编号]` | 恢复二进制 |
| `cc binver` | 查看二进制版本 |

```bash
# 改配置前先备份（强烈推荐）
cc backup

# 出问题恢复
cc backup list
cc backup restore 1
cc restart
```

---

## 七、API 与配置文件

| 命令 | 作用 |
|------|------|
| `cc apiconf` | 查看/修改 API 配置（地址/端口/密钥）|
| `cc patch <字段> <值>` | **动态 PATCH 修改配置（零重启生效）**|
| `cc profile` | 配置文件管理（crontab/调优持久化）|
| `cc tun` | TUN 模式管理 |

### cc patch（零重启改配置）
用于不需要重启就能生效的参数，例如：

```bash
# 动态改 AUTO tolerance（立即生效，不断网）
cc patch tolerance 120

# 动态改测速间隔
cc patch interval 300
```

> ⚠️ **重要**：
> - `cc patch`（PATCH /configs）只支持 proxy-groups 类参数，安全零重启 ✅
> - `PUT /configs` 整体热重载（API 直接调）**会触发 1053 DNS 端口冲突断网，禁用** ❌
> - fake-ip-filter/规则/代理节点等改动 → 改 config.yaml 后 `cc restart`

---

## 八、crontab 内置任务（自动运行）

本套配置在 crontab 中自动注册了这些任务（无需手动管理）：

| 任务 | 频率 | 作用 |
|------|------|------|
| tune-tolerance.sh | 每10分钟 | 自适应 tolerance 降级（与测速同频）|
| dns-guard | 每10分钟 | DNS 上游防重置 + dnsmasq OOM 保护 |
| fix-nodes | 每30分钟 | 节点 IP 自愈 |
| clash-logrotate | 每10分钟 | 日志轮转（上限100KB）|
| drop_caches | 每小时 | 内存清理 |
| cc.sh sub-update | 每3天 | 订阅更新 |
| geosite-cn-update | 每3天6:10 | 社区白名单条件下载(零重启, `cc sub-sync auto` 生成) |
| fakeip-cn-auto sync | 每3天6:10 | 自学习收集(零重启, `cc sub-sync auto` 生成) |

检查当前任务：
```bash
crontab -l
```