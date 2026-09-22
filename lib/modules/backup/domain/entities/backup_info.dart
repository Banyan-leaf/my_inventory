/// 模块：backup / domain / entities
/// 职责：备份元信息。描述一次备份/恢复的结果。
/// 约束：不可变，纯数据。
library;

/// 备份文件元信息。
class BackupInfo {
  /// 备份文件绝对路径。
  final String filePath;

  /// 导出时间。
  final DateTime exportedAt;

  /// schema 版本。
  final int schemaVersion;

  /// 各表行数。key 为表名。
  final Map<String, int> tableCounts;

  /// 文件大小（字节）。
  final int fileSize;

  const BackupInfo({
    required this.filePath,
    required this.exportedAt,
    required this.schemaVersion,
    required this.tableCounts,
    required this.fileSize,
  });

  /// 总行数。
  int get totalRows =>
      tableCounts.values.fold(0, (sum, v) => sum + v);
}

/// 恢复结果。
class RestoreResult {
  /// 各表恢复的行数。
  final Map<String, int> tableCounts;

  /// 是否成功。
  final bool success;

  /// 失败原因。成功时为 null。
  final String? error;

  const RestoreResult({
    required this.tableCounts,
    required this.success,
    this.error,
  });
}