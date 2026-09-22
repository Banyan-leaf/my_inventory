/// 模块：backup / domain / ports
/// 职责：backup 模块对外契约。
/// 依赖：同模块 entities/backup_info.dart。
/// 约束：
///   1. 导出为单文件 JSON。
///   2. 恢复会先清空所有表再导入，属破坏性操作。
///   3. 文件路径由调用方提供（UI 层决定存放位置）。
library;

import '../entities/backup_info.dart';

/// backup 模块对外端口。
abstract class BackupPort {
  /// 导出全部数据到 [targetPath]。
  ///
  /// [targetPath] 为完整文件路径。父目录必须存在。
  /// 返回备份元信息。
  /// 抛出 [ValidationException] 当路径非法。
  /// 抛出 [AppDatabaseException] 当文件写入失败。
  Future<BackupInfo> export(String targetPath);

  /// 从 [sourcePath] 恢复数据。
  ///
  /// 会先清空所有表，再按依赖顺序导入。
  /// 返回恢复结果。
  /// 抛出 [ValidationException] 当文件不存在或格式错误。
  Future<RestoreResult> restore(String sourcePath);

  /// 生成建议的备份文件名（不含目录）。
  ///
  /// 格式：inventory_backup_yyyyMMdd_HHmmss.json
  String suggestedFileName();

  /// 生成默认导出目录（应用文档目录）。
  Future<String> defaultDirectory();
}