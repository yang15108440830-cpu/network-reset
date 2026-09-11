# 网络重置工具
> 菜单式双功能：① 一键关系统代理 + 刷 DNS（免管理员）；② 清理 VPN/代理软件异常退出后的残留路由（需管理员），用于 TUN/VPN 崩溃断网的自救

## 技术栈与版本
- Windows 批处理（`reg` + `ipconfig` + `ping` + `route`）+ 内置 PowerShell 网络模块（`Get-NetAdapter` / `Get-NetRoute` / `Remove-NetRoute`），无任何第三方依赖
- Windows 10 及以上（依赖 PowerShell NetAdapter/NetRoute 模块）

## 功能说明

### 菜单 [1] 快速重置（免管理员）
原 4 步流程：查代理 → 关系统代理（HKCU `ProxyEnable` 置 0）→ 刷 DNS 缓存 → 验证，随后展示 IP 配置并 ping 测连通性。

### 菜单 [2] 清理 VPN/代理残留路由（需管理员，选中后才弹 UAC）
典型场景：Clash/v2rayN TUN 模式、OpenVPN/WireGuard 等异常退出（崩溃、强杀进程）后，路由表残留指向已失效虚拟网卡的路由，导致断网。

处理流程（新开的提权窗口中执行）：
1. 展示所有网卡及状态（`Get-NetAdapter`）
2. 展示当前完整 IPv4 路由表（`route print -4`）
3. 扫描并删除**孤儿路由**：绑定到「不存在 / Not Present / Disconnected / Disabled / Broken」网卡的 IPv4 活动路由，逐条 `Remove-NetRoute` 删除
4. 刷 DNS、回显清理后的路由表、ping 验证

**安全边界**：状态为 Up 的正常网卡（包括物理网卡、WSL/Hyper-V 虚拟交换机、正常工作中的 TUN 网卡）的路由一律不碰；Local 协议路由与 loopback（127.x）路由排除在外。

## 目录结构
```
网络重置工具/
├─ Network_Reset_Quick.bat    # 源码即启动入口（菜单式，运行完返回菜单）
├─ README.md                  # 本文件
└─ .gitignore
```

## 启动方式
- 双击 `Network_Reset_Quick.bat`，按菜单输入 1/2/3
- 或命令行：`C:\Users\YY\Desktop\自研工具\网络重置工具\Network_Reset_Quick.bat`
- 直接执行 `Network_Reset_Quick.bat /ROUTEFIX` 可跳过菜单直达路由清理（仍会请求 UAC）

## 端口
无（本工具用于修网络，自身不监听端口）

## 数据文件说明
- 无持久化数据文件；仅改注册表项 `HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings` 的 `ProxyEnable`（置 0）、删路由表 IPv4 活动条目

## 已知限制
- **只关代理不清代理地址**：`ProxyServer` 注册表值保留（仅 ProxyEnable 置 0），Clash/v2rayN 等重新打开"系统代理"开关时无需重填地址，但也意味着代理地址一直留在注册表里
- 快速重置关的是**当前用户（HKCU）的 IE/WinINET 系统代理**；WinHTTP 代理（`netsh winhttp show proxy`）与浏览器自身代理设置不在处理范围
- **路由清理无法覆盖"TUN 网卡仍为 Up 但代理进程已死"的情况**（部分 TUN 伪网卡会常驻 Up 状态）：此时孤儿检测不触发，建议先重启代理软件、或在"网络连接"里禁用再启用对应 TUN 网卡后再跑本工具
- 路由清理只处理 IPv4 活动路由，不处理持久化路由（Persistent Routes）与 IPv6 路由
- 适配器状态按英文枚举值匹配（Up/Disconnected/Not Present 等）；实测 CIM 枚举在中文系统同样返回英文（已验证），如遇本地化异常会导致漏删（只漏删不误删，属安全侧失败）
- 代理关闭后部分已打开的浏览器需重启才生效（浏览器启动时读取代理设置）
- `ping www.baidu.com` 在纯内网环境会失败，属正常
- 快速重置无需管理员；路由清理需管理员（UAC 提权，取消 UAC 则不会执行清理）

## 迭代记录
- 2026-08-25 迁移入库：自工具根目录散置状态归入本文件夹，按 create-tool skill 规范补 README/.gitignore 并 git 化（工具实际创建日期早于本次迁移，bat 末次修改 2026-07-29）
- 2026-09-04 新增：菜单式单入口（原快速重置为菜单项 1）；新增菜单项 2"清理 VPN/代理残留路由"——基于 Get-NetAdapter/Get-NetRoute 孤儿路由检测 + Remove-NetRoute 删除，选中时按需 UAC 提权，新增 `/ROUTEFIX` 直达参数
