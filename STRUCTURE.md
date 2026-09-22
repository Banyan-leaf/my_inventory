STRUCTURE.md

# 项目结构快照

生成日期：2026-09-16
Schema 版本：v8

## 顶层目录
my_inventory/
├── lib/ Dart 源码
├── windows/ Windows 平台壳（C++ / RC）
├── test/ 测试
├── pubspec.yaml 依赖声明
├── pubspec.lock 依赖锁定（提交 git）
├── README.md 项目说明
├── STRUCTURE.md 本文件
└── build/ 构建产物（不提交）

## lib/ 完整结构
lib/
├── main.dart 应用入口 + 底部导航壳
│
├── app/ 应用层
│ ├── bootstrap.dart 启动装配（端口注册顺序）
│ ├── use_cases/
│ │ └── create_item_from_candidate_use_case.dart
│ └── pages/
│ ├── items_page.dart 物品列表 + 批量操作
│ ├── item_edit_page.dart 物品编辑（含标签多选）
│ ├── location_page.dart 位置树 + 物品计数
│ ├── suggest_page.dart 联想录入
│ ├── candidates_page.dart 词库高级管理
│ ├── category_page.dart 分类管理
│ ├── tag_page.dart 标签管理
│ ├── settings_page.dart 设置（导出/分类/标签/外观）
│ └── dashboard/
│ ├── dashboard_page.dart 仪表盘主页面
│ └── widgets/
│ ├── overview_cards.dart
│ ├── category_pie.dart
│ ├── status_pie.dart
│ ├── value_trend_chart.dart
│ ├── intake_activity_chart.dart
│ ├── location_ranking.dart
│ └── expiry_list.dart
│
├── core/ 基础设施（零业务依赖）
│ ├── di/
│ │ └── port_registry.dart 统一端口注册中心
│ ├── database/
│ │ ├── app_database.dart 连接管理 + 建表 SQL
│ │ └── database_factory_setup.dart 平台适配
│ ├── error/
│ │ └── app_exception.dart 全局异常
│ ├── refresh/
│ │ └── app_refresh.dart 全局刷新通知器
│ ├── theme/
│ │ └── theme_manager.dart 主题管理
│ └── utils/
│ └── app_logger.dart 日志
│
└── modules/ 业务模块
├── location/ 位置树
│ ├── domain/
│ │ ├── entities/location.dart
│ │ └── ports/{location_port.dart, location_repo.dart}
│ ├── data/
│ │ ├── dao/location_dao.dart
│ │ └── port/location_port_impl.dart
│ └── location_module.dart
│
├── category/ 分类树
│ └── （结构同上）
│
├── tag/ 标签 + 物品-标签多对多
│ └── （结构同上，含 item_tag 表操作）
│
├── event/ 事件时间线
│ └── （结构同上）
│
├── item/ 物品主表
│ └── （结构同上，含 ItemBrief / ItemSnapshot / ItemQuery）
│
├── attachment/ 附件（DB + 文件系统双写）
│ ├── domain/
│ ├── data/
│ │ ├── dao/attachment_dao.dart
│ │ ├── port/attachment_port_impl.dart
│ │ └── storage/attachment_storage.dart
│ └── attachment_module.dart
│
├── suggestion/ 联想词库
│ ├── domain/
│ ├── data/
│ │ ├── dao/{candidate_dao.dart, candidate_item_dao.dart}
│ │ ├── port/suggestion_port_impl.dart
│ │ ├── builtin_words.dart 聚合器
│ │ └── words/ 16 大类词库
│ │ ├── tools.dart
│ │ ├── digital.dart
│ │ ├── kitchen.dart
│ │ ├── medicine.dart
│ │ ├── stationery.dart
│ │ ├── daily.dart
│ │ ├── cleaning.dart
│ │ ├── hardware.dart
│ │ ├── clothing.dart
│ │ ├── sports.dart
│ │ ├── baby.dart
│ │ ├── pet.dart
│ │ ├── automotive.dart
│ │ ├── furniture.dart
│ │ ├── appliance.dart
│ │ ├── gardening.dart
│ │ └── other.dart
│ └── suggestion_module.dart
│
├── stats/ 统计聚合
│ ├── domain/
│ ├── data/port/stats_port_impl.dart
│ └── stats_module.dart
│
└── backup/ 导入导出
├── domain/
├── data/port/backup_port_impl.dart
└── backup_module.dart

## 端口注册顺序

`bootstrap.dart` 按依赖方向严格注册：
LocationModule 无依赖

CategoryModule 无依赖

TagModule 无依赖

EventModule 无依赖

ItemModule 惰性 resolve Location / Category / Event

AttachmentModule 无外部 Port 依赖

SuggestionModule 异步 seed 词库，惰性 resolve Item

StatsModule 惰性 resolve Item / Location / Category

BackupModule 直连 DB

## 页面与 Port 关系

| 页面 | 依赖 Port |
|---|---|
| ItemsPage | ItemPort |
| ItemEditPage | ItemPort / LocationPort / CategoryPort / TagPort |
| LocationPage | LocationPort + ItemPort（app 层组装） |
| SuggestPage | SuggestionPort + CreateItemFromCandidateUseCase |
| CandidatesPage | SuggestionPort |
| CategoryPage | CategoryPort |
| TagPage | TagPort |
| DashboardPage | StatsPort |
| SettingsPage | BackupPort + ThemeManager |

## 数据库表

| 表 | 归属 | 主要列 |
|---|---|---|
| location | location | id, name, parent_id, type, note |
| category | category | id, name, parent_id, icon, sort_order |
| tag | tag | id, name, color |
| item_tag | tag | item_id, tag_id |
| event | event | id, item_id, type, event_date, from/to_location_id, ... |
| item | item | id, name, aliases, category_id, location_id, quantity, status, price, ... |
| attachment | attachment | id, item_id, event_id, file_path, mime_type, file_size |
| candidate | suggestion | id, word, normalized, source, group_name, item_id, hit_count |
| candidate_item | suggestion | candidate_id, item_id, linked_at |

## 数据流
UI 事件
↓
UseCase（如需跨模块）
↓
PortRegistry.resolve<XxxPort>()
↓
XxxPortImpl（编排）
↓
XxxDao + 其他模块 Port
↓
SQLite / 文件系统
↓
AppRefresh.bump()（通知其他页面）

## 关键文件说明

| 文件 | 作用 |
|---|---|
| `core/di/port_registry.dart` | 全局端口注册中心，模块通信唯一入口 |
| `core/database/app_database.dart` | 连接管理 + 全库 schema |
| `core/refresh/app_refresh.dart` | 跨页面数据同步 |
| `core/theme/theme_manager.dart` | 明暗模式持久化 |
| `app/bootstrap.dart` | 装配顺序 |
| `modules/suggestion/data/builtin_words.dart` | 词库聚合 |

## 修改依赖时的注意事项

**关键包已锁版本**，见 `pubspec.yaml` 的 `dependency_overrides`。

**不要**：
- 删除 `dependency_overrides`
- 给关键包加 `^` 前缀
- 运行 `flutter pub upgrade`

**如果必须升级**：

1. 先备份 `pubspec.yaml` 和 `pubspec.lock`
2. 升级后跑 `flutter build windows --release` 验证
3. 失败立即还原备份

## Release 构建检查清单

1. `flutter analyze` 无错误
2. `flutter build windows --release` 成功
3. `build\windows\x64\runner\Release\` 存在 exe + `flutter_windows.dll` + `data\`
4. 双击 exe 能启动，5 个 tab 正常
5. 窗口标题显示 `Personal Inventory`（无乱码）
6. 数据库文件在 `Documents\inventory.db`

---

生成于 2026-09-16