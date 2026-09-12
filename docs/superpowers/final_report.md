# 时账 TimeBook · 最终项目总结

> 日期：2026-09-12 · 状态：M0–M7 全部完成 · MIT 开源
> 仓库：https://github.com/KaltsitLLL/timebook（Public · 55 commits）

---

## 1. 项目概述

**时账 TimeBook** 是一款本地优先、全平台（Android / iOS / Windows / macOS）的个人「记账 + 待办 + 番茄钟」一体化应用，从零编写、100% 自研。数据保存在本地 SQLite，无账号、无服务端；AI 记账（可选）使用智谱 GLM-4-Flash，API Key 存于系统安全存储（DPAPI / Keystore）。

**项目动机（面试 + 自用）**：为考研复试提供可完整演示、可开源、commit 历史可追踪的个人项目；同时满足日常记账刚需——重点是根治支付宝/微信账单导入"几行错误"与退款虚增收支两大痛点（源自对 Veri Fin 的使用体验）。

## 2. 技术栈与架构

| 领域 | 选型 |
|---|---|
| 框架 | Flutter 3.47 / Dart 3.13 |
| 状态管理 | flutter_riverpod 2.6.1 |
| 数据库 | drift 2.31 (SQLite)，schema v1→v4 全量迁移 |
| 图表 | fl_chart 0.68 |
| AI | 智谱 GLM-4-Flash（OpenAI 兼容，http MockClient 可测） |
| 安全存储 | flutter_secure_storage（Windows DPAPI / 移动 Keystore） |
| 敏感依赖 | http, yaml, intl, gbk_codec, file_picker |

```
lib/
├── core/        # 主题(M3 蓝白 seed #3F77B6)、数据库(迁移)、金额/日期工具
└── features/    # bookkeeping / focus / import / ai / daily / stats（各域 data→domain→presentation）
```

架构原则：feature 模块化（新功能=新增目录，不触碰既有代码）；金额一律以「分」存整数；所有统计按**净额**（退款冲抵后）计算；外部依赖均抽象为可注入接口（http.Client / Storage / 时钟）保障可测性。

## 3. 功能清单（全部完成并通过验收）

- **记账**：多账本 / 多账户 / 二级分类 / 流水明细 / 金额千分位；`refunded_cents` 退款冲抵，退款不新增行、原行标注，统计按净额
- **预算**：总预算 + 分类预算、月度进度、超支/预警高亮（>80% 琥珀、≥100% 红）、剩余日均
- **统计**：近 6 个月收支柱状图、本月分类占比环形图与排行（净额）
- **待办 + 番茄钟（签名功能）**：任务/项目 CRUD、**短语法**快速创建（`整理周报 +work 45m #汇总 @明天`）、**四象限视图**、**绝对时间戳计时器**（剩余 = endAt − now，切后台自动补偿、可注入时钟）、任务绑定联动、每日专注统计
- **账单导入**：YAML 声明式模板引擎、**错误行显式化**（永不静默丢行）、重复去重（order_id / importKey）、周期记账（到期生成待确认）、**退款冲抵**、导入批次留痕
- **AI 记账**（可选）：一句话 → GLM 结构化草稿 → 可编辑确认页 → 落库；设置页管理 Key/Endpoint，隐私边界明示
- **每日小结**：收工一键生成当日「番茄 / 专注分钟 / 支出净额 / 完成任务」并存档回看

## 4. 里程碑与质量数据

| 里程碑 | 内容 | 验收 |
|---|---|---|
| M0–M1 | 脚手架 + 记账核心（Drift 五表） | ✅ |
| M2 | 图表仪表盘 + 月份筛选 + 千分位 | ✅ |
| M3 | 预算体系 | ✅ |
| M4 | 待办 + 番茄钟（v2 迁移） | ✅ |
| M5 | 账单导入（v3 迁移） | ✅ |
| M6 | AI 记账 | ✅ |
| M7 | 每日小结（v4 迁移）+ README/License + 开源发布 | ✅ |

- **测试**：63 个单元/组件测试全绿（数据层、纯函数解析器、计时器、导入管线、全 UI 流程）
- **静态检查**：`flutter analyze` 0 问题
- **构建**：Windows 桌面 debug 构建通过
- **开发流程**：brainstorming → spec → writing-plans → subagent-driven（每任务两段审查）→ TDD 全流程落地，全部文档入库 `docs/superpowers/`

## 5. 面试谈资（设计亮点）

1. **金额以分存储 + 退款净额统计**：杜绝浮点误差；退款只更新原行 `refunded_cents`（支持部分退款），不新增收入行，所有聚合按净额——"实际花了多少钱"不被退款虚增（源自 Veri Fin 痛点）
2. **绝对时间戳番茄计时器**：剩余 = endAt − now，UI 只做展示层；切后台/锁屏自动补偿；可注入时钟使测试完全确定
3. **导入错误行显式化**：每行要么解析成功要么进错误清单（含原因 + 原始快照），绝不静默丢弃；YAML 模板 + fixtures 锁行为防平台改版
4. **可测架构**：GlmChatClient 注入 http.Client、KeyValueStorage 注入、计时/解析全纯函数——每层可独立单测（63 tests 支撑）
5. **数据库迁移链**：schema v1→v4 逐版本 onUpgrade 新建表，存量数据无损升级，迁移用例守护
6. **M3 规范落地**：ColorScheme.fromSeed(#3F77B6) 蓝白浅色调、冷色图表板、M3 组件体系

## 6. 开源与后续

- 仓库：https://github.com/KaltsitLLL/timebook（Public，55 commits，MIT，README 含功能/架构/开发命令）
- 演示脚本：面试临近时按最新功能一次性编写（已从里程碑移除，避免过时）
- **未来扩展池**（见 spec §11，不阻塞）：ML Kit 原生 OCR（M6 补丁）、语音记账、云同步（WebDAV/iCloud/Supabase）、多币种、发薪日预算周期、AI 财务问答、储蓄罐、应用锁、桌面小组件、Flowtime、插件系统等

## 7. 使用提示

- 桌面可执行文件：`timebook/build/windows/x64/runner/Debug/timebook.exe`
- AI 功能需在「设置 → AI 设置」填入智谱 API Key（open.bigmodel.cn 免费申请，新用户赠 2000 万 token）
- 首次使用建议先「记一笔」或从流水页「导入」微信/支付宝导出 CSV 体验完整链路