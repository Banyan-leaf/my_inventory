/// 模块：backup / data / port
/// 职责：BackupPort 的实现。
/// 依赖：
///   - sqflite、dart:io、dart:convert、path、path_provider
///   - core/error
///   - core/database（获取 schemaVersion）
/// 约束：
///   1. 是本工程唯一直接操作所有表的模块。
///      理由：备份的是原始数据，走 Port 会需要所有模块加 export/import 方法，
///      侵入性过大。这是"基础设施模块"的合理例外。
///   2. 表名与依赖顺序硬编码在文件中，新增模块时必须同步更新。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/error/app_exception.dart';
import '../../domain/entities/backup_info.dart';
import '../../domain/ports/backup_port.dart';

/// BackupPort 默认实现。
class BackupPortImpl implements BackupPort {
  final AppDatabase _db;

  BackupPortImpl(this._db);

  /// 表清单。**导入顺序**与**导出顺序**。
  ///
  /// 导入顺序必须遵守外键依赖：被依赖的表先插入。
  /// 当前表间无硬外键，顺序仅影响可读性，但保持一致性便于后续加外键。
  static const List<String> _tables = [
    'location',
    'category',
    'tag',
    'event',
    'item',
    'attachment',
    'candidate',
  ];

  /// 表在 JSON 中的顶层 key。
  static const String _payloadKey = 'tables';

  @override
  Future<BackupInfo> export(String targetPath) async {
    if (targetPath.trim().isEmpty) {
      throw const ValidationException('导出路径不能为空');
    }

    final raw = _db.raw;
    final tables = <String, List<Map<String, Object?>>>{};

    for (final t in _tables) {
      final rows = await raw.query(t);
      tables[t] = rows;
    }

    final payload = {
      'version': AppDatabase.schemaVersion,
      'exported_at': DateTime.now().toIso8601String(),
      _payloadKey: tables,
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    try {
      final file = File(targetPath);
      await file.writeAsString(jsonStr, flush: true);
      final stat = await file.stat();

      return BackupInfo(
        filePath: targetPath,
        exportedAt: DateTime.now(),
        schemaVersion: AppDatabase.schemaVersion,
        tableCounts: {for (final e in tables.entries) e.key: e.value.length},
        fileSize: stat.size,
      );
    } catch (e) {
      throw AppDatabaseException('导出失败: $e', cause: e);
    }
  }

  @override
  Future<RestoreResult> restore(String sourcePath) async {
    if (sourcePath.trim().isEmpty) {
      throw const ValidationException('导入路径不能为空');
    }
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw ValidationException('文件不存在: $sourcePath');
    }

    late final Map<String, dynamic> payload;
    try {
      final content = await file.readAsString();
      payload = jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      throw ValidationException('JSON 解析失败: $e');
    }

    final tablesRaw = payload[_payloadKey];
    if (tablesRaw is! Map) {
      throw const ValidationException('备份文件缺少 tables 字段');
    }

    final counts = <String, int>{};

    try {
      await _db.raw.transaction((txn) async {
        // 1. 清空所有表。逆序避免潜在外键冲突。
        for (final t in _tables.reversed) {
          await txn.delete(t);
        }

        // 2. 按顺序导入。
        for (final t in _tables) {
          final rows = tablesRaw[t];
          if (rows == null) {
            counts[t] = 0;
            continue;
          }
          if (rows is! List) {
            throw ValidationException('表 $t 的格式不是数组');
          }
          var inserted = 0;
          for (final r in rows) {
            if (r is! Map) continue;
            await txn.insert(
              t,
              r.map((k, v) => MapEntry(k.toString(), v)),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            inserted++;
          }
          counts[t] = inserted;
        }
      });

      return RestoreResult(tableCounts: counts, success: true);
    } catch (e) {
      return RestoreResult(
        tableCounts: const {},
        success: false,
        error: e.toString(),
      );
    }
  }

  @override
  String suggestedFileName() {
    final now = DateTime.now();
    String pad(int n) => n.toString().padLeft(2, '0');
    final ts =
        '${now.year}${pad(now.month)}${pad(now.day)}_${pad(now.hour)}${pad(now.minute)}${pad(now.second)}';
    return 'inventory_backup_$ts.json';
  }

  @override
  Future<String> defaultDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }
}