# 同类项目调研（Peer Research）

调研日期：2026-11-19。目的：为 NetScope 寻找可借鉴的功能与设计。

## 项目速览（按 star 排序）

| 项目 | Star | 语言/协议 | 与 NetScope 的相关度 |
|------|------|-----------|----------------------|
| exelban/stats | 43.5k | Swift / MIT | 菜单栏系统监控，Network 模块含按进程网速、连通性 ping、历史图表 |
| GyulyVGC/sniffnet | 43.1k | Rust / Apache-2.0 | 抓包级流量监控：进程带宽、ASN+域名、6000+ 服务识别、收藏、事件通知、IP 黑名单 |
| domcyrus/rustnet | 5.2k | Rust / Apache-2.0 | 终端 TUI：DPI 协议识别（TLS SNI/DNS/QUIC）、被动 DNS、PCAP 导出 |
| matthart1983/netwatch | 3.6k | Rust / MIT | 每连接延迟 sparkline、逐跳延迟预算、自动诊断异常 |
| olalie/tapmap | 1.7k | Python / MIT | **概念几乎相同**：socket→GeoIP→地图，另有 30 天活动历史、Insights、显著连接检测、开放端口视图 |
| aixisstudio/Snitch | 809 | Python / AGPL | 监控+出站防火墙，本地优先 |
| objective-see/Netiquette | 393 | ObjC / GPL-3.0 | macOS 连接监控。**与我们用同一套 NStatManager C 块回调 API**；反向 DNS、默认隐藏 Apple 进程、按 UUID 缓存进程、JSON 导出、CLI 模式 |
| momenbasel/puresnitch | 229 | Swift / MIT | 技术栈最接近：SwiftUI 世界地图 + 菜单栏；但走 pf 防火墙路线 |
| isaaclins/freesnitch | 51 | Swift / MIT | 每进程过滤、流量地图、DoH |
| ImanMontajabi/Rat | 32 | Swift / MIT | **需求背景最接近**：离线 DB-IP Lite（免 license）、服务名（443·HTTPS）、ASN 归属（AS13335 Cloudflare）、via 进程归因、5m/1h/1d/1w 流量图、离线地图弧线+城市钉 |

## 可借鉴点（映射到 NetScope）

### 高价值低成本
1. **端口→服务名本地表**（Rat / Sniffnet）：`TCP 443 · HTTPS`、`5223 · APN`、`853 · DoH`。一张静态表即可，连接行与详情面板直接可读。
2. **ASN/网络归属显示**（Rat / Sniffnet）：每条连接显示 `AS13335 Cloudflare, Inc.`。GeoInfo 已带 `asn` 字段（ip-api 回传），目前 UI 完全没展示；可加 DB-IP ASN Lite 离线库。
3. **默认隐藏 Apple/系统进程开关**（Netiquette）：减少列表噪音，一个 Toggle。
4. **菜单栏 popover 增强**（puresnitch / stats）：实时上下行吞吐迷你图、最近活动流、ping 连通性。

### 高价值中等成本
5. **历史/趋势**：滚动 ring buffer 记录每秒聚合速率 → 详情面板与 popover 画 5m/1h sparkline（tapmap 30 天历史 / stats / Rat 多时间窗）。
6. **“新连接”显著事件 + 通知**（tapmap Significant Connections）：新进程/新国家/新 ASN 首次出现记入列表并可弹通知。
7. **反向 DNS**（Netiquette / Rat）：`getnameinfo` 本地解析主机名，缓存，设置里可开关。
8. **开放端口视图**（tapmap / rustnet Host sockets）：本机 Listen 端口及所属进程。
9. **DB-IP Lite 作为免 license 离线库**（Rat / iNTM）：CC-BY 协议、直接下载无需注册，可消除 MaxMind 注册的首次使用摩擦。

### 超出当前范围（不建议现在做）
- DPI/协议识别、SNI 解析（rustnet）
- 防火墙规则/拦截（puresnitch / LuLu / freesnitch）
- PCAP 导出、自动诊断（netwatch）
- 威胁情报集成（AbuseIPDB 等）

## 对我们已有实现的验证
- Netiquette 的 `Monitor.m` 与我们的 `NetworkStatisticsSource` 使用完全相同的 NStatManager 块回调模式（SetDescriptionBlock/SetRemovedBlock + 双查询），说明该私有 API 用法是社区标准做法；其按 `kNStatSrcKeyUUID` 用 NSCache 缓存进程的做法可参考，但我们的两个数据源已直接给出 processName，收益有限。
- stats 的 issue #606（nettop CPU 高占用）提示常驻 nettop 需控制刷新频率——我们已用 `-s` 跟随设置间隔。
