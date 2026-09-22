![Flutter](https://img.shields.io/badge/Flutter-3.47-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13-blue?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)
# 个人物品管理系统

markdown
# 个人物品管理系统

Flutter + SQLite 桌面应用。本地优先、单用户、架构解耦、强注释。

## 环境要求

- Flutter 3.47+（stable channel）
- Visual Studio 2022+（含"使用 C++ 的桌面开发"工作负载）
- Windows 10/11 64 位

### 环境搭建

```powershell
mkdir C:\dev
cd C:\dev
git clone https://github.com/flutter/flutter.git -b stable --depth 1

[System.Environment]::SetEnvironmentVariable(
  'Path',
  [System.Environment]::GetEnvironmentVariable('Path','User') + ';C:\dev\flutter\bin',
  'User'
)
[System.Environment]::SetEnvironmentVariable('PUB_HOSTED_URL','https://pub.flutter-io.cn','User')
[System.Environment]::SetEnvironmentVariable('FLUTTER_STORAGE_BASE_URL','https://storage.flutter-io.cn','User')

# 重开 PowerShell
flutter doctor
构建与运行
powershell
cd C:\dev\projects\my_inventory

flutter pub get
flutter analyze
flutter run -d windows                    # 开发调试
flutter build windows --release           # 发布构建
Release 产物：build\windows\x64\runner\Release\my_inventory.exe

数据位置
数据库：%USERPROFILE%\Documents\inventory.db

附件：%USERPROFILE%\Documents\my_inventory_photos\

备份：%USERPROFILE%\Documents\inventory_backup_*.json

架构
六边形（端口-适配器）架构 + 模块化单体。

text
lib/
├── app/         应用层（UI + 跨模块用例）
├── core/        基础设施（DI、数据库、主题、错误）
└── modules/     业务模块
    ├── location/     位置树
    ├── category/     分类
    ├── tag/          标签
    ├── event/        事件时间线
    ├── item/         物品
    ├── attachment/   附件
    ├── suggestion/   联想词库
    ├── stats/        统计聚合
    └── backup/       导入导出
每个模块内部：

text
xxx/
├── domain/
│   ├── entities/     实体
│   └── ports/        契约
├── data/
│   ├── dao/          SQL
│   └── port/         实现
└── xxx_module.dart   装配入口
解耦规则
模块间只能通过 PortRegistry.instance.resolve<XxxPort>() 通信

表归属唯一模块，跨模块访问走 Port

domain 层不依赖 Flutter / dart:io

端口注册集中在 bootstrap.dart

backup 是唯一直接操作所有表的例外

端口清单
端口	模块	依赖
LocationPort	location	无
CategoryPort	category	无
TagPort	tag	无
EventPort	event	无
ItemPort	item	Location / Category / Event
AttachmentPort	attachment	无
SuggestionPort	suggestion	Item
StatsPort	stats	Item / Location / Category
BackupPort	backup	无（直连 DB）
数据库表
表	归属	说明
location	location	位置树
category	category	分类树
tag	tag	标签
item_tag	tag	物品-标签多对多
event	event	事件时间线
item	item	物品主表
attachment	attachment	附件元数据
candidate	suggestion	候选词
candidate_item	suggestion	候选词-物品多对多
当前 schema 版本：v8

依赖版本锁定
关键包使用精确版本号，避免自动升级引入问题：

yaml
dependencies:
  sqflite: 2.3.3
  sqflite_common_ffi: 2.3.2
  path_provider: 2.1.4
  ...

dependency_overrides:
  path_provider: 2.1.4
  path_provider_foundation: 2.4.1
  sqflite: 2.3.3
  sqflite_common_ffi: 2.3.2
不要删除 dependency_overrides。它们防止 Release 构建失败。

添加新模块
建目录 lib/modules/xxx/{domain/{entities,ports},data/{dao,port}}

写 6 个文件：entity / 对外 Port / 对内 Repo / Dao / PortImpl / Module

app_database.dart 的 _schema 加建表 SQL，_dropAll 加 DROP

schemaVersion +1（触发重建）

bootstrap.dart 加 XxxModule.register(db)

分享给他人
flutter build windows --release

打包 build\windows\x64\runner\Release\ 整个目录

对方解压后双击 exe 即可，无需安装 Flutter / VS

已知限制
Web 端不支持

schema 变更会清空数据（无 migration）

单用户，无云同步

附件图片上传 UI 未实现（Port 层已就绪）

借出 / 提醒模块数据模型已预留，UI 未实现

开发注意事项
不要：

开 flutter config --enable-native-assets（会引入 iOS 依赖问题）

在 C++ / RC 文件里写中文（MSVC 按 GBK 解析必乱码）

用 Set-Content / Out-File 写 Dart 文件（可能带 BOM）

加 dependency_overrides 除非明确知道在做什么

要：

关键包用精确版本号，不用 ^

每周跑一次 flutter build windows --release

pubspec.lock 提交到 git

用 .NET 方式写文件：[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))

许可
MIT License

生成于 2026-09-16

## License

本项目采用 [MIT License](LICENSE) 开源。

Copyright (c) 2026 Banyan-leaf
