/// 模块：status / data / dao
/// 职责：item_status 表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/item_status.dart';
import '../../domain/ports/status_repo.dart';

class StatusDao implements StatusRepo {
  static const String tableName = 'item_status';

  final Database _db;
  StatusDao(this._db);

  @override
  Future<List<ItemStatus>> findAll() async {
    final rows = await _db.query(
      tableName,
      orderBy: 'sort_order ASC, label ASC',
    );
    return rows.map(ItemStatus.fromMap).toList();
  }

  @override
  Future<ItemStatus?> findByKey(String key) async {
    final rows = await _db.query(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ItemStatus.fromMap(rows.first);
  }

  @override
  Future<void> insert(ItemStatus status) async {
    try {
      await _db.insert(
        tableName,
        status.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('写入状态失败', cause: e);
    }
  }

  @override
  Future<void> update(ItemStatus status) async {
    await _db.update(
      tableName,
      {'label': status.label, 'color': status.color, 'sort_order': status.sortOrder},
      where: 'key = ?',
      whereArgs: [status.key],
    );
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $tableName');
    return (rows.first['c'] as int?) ?? 0;
  }
}