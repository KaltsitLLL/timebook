# 时账 TimeBook

本地优先、全平台（Android/iOS/Windows/macOS）的个人记账 + 待办 + 番茄钟应用。数据 100% 存于本地 SQLite，支持账单导入（微信/支付宝 CSV）、退款冲抵、AI 对话记账（智谱 GLM-4-Flash，可选）。

## 功能
- **记账**：多账本/多账户/二级分类/流水；金额以「分」存储，统计按净额（退款冲抵）
- **预算**：总预算 + 分类预算、月度进度、超支/预警高亮、剩余日均
- **统计**：近 6 个月收支柱状图、本月分类占比与排行
- **待办 + 番茄钟**：任务/项目、短语法快速创建（`整理周报 +work 45m #汇总 @明天`）、四象限视图、绝对时间戳计时器（切后台自动补偿）、任务联动
- **账单导入**：YAML 声明式模板、错误行显式化、重复去重、周期记账、退款冲抵
- **AI 记账**（可选）：设置 GLM API Key 后一句话记账，确认页人工复核后入账

## 技术栈
Flutter · Riverpod · Drift(SQLite) · fl_chart · intl · http · flutter_secure_storage

## 架构
```
lib/
├── core/          # 主题(M3 蓝白)、数据库(迁移 v1..v4)、工具(金额/日期)
└── features/      # bookkeeping / focus / import / ai / daily / stats
```
每个 feature：data（Drift DAO）→ domain（服务/纯函数）→ presentation（Riverpod + UI）。

## 开发
```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test    # 63 个测试
flutter run -d windows
```

## 开源协议
MIT License（见 LICENSE）。基于本人考研复试个人项目，从零编写。