/// 模块：event / data / dao
/// 职责：event 表的 SQL 操作。
/// 依赖：sqflite、core/error、同模块 domain。
/// 约束：
///   1. 只做 CRUD。
///   2. 不 import 其他模块。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/event.dart';
import '../../domain/ports/event_repo.dart';

/// event 表的 SQLite 实现。
///
/// 生命周期：由 EventModule 创建，与应用同生命周期。
/// 线程模型：依赖 sqflite 单连接，方法可并发。
class EventDao implements EventRepo {
  static const String tableName = 'event';

  final Database _db;
  EventDao(this._db);

  @override
  Future<int> insert(Event event) async {
    try {
      return await _db.insert(tableName, event.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('写入事件失败', cause: e);
    }
  }

  @override
  Future<List<Event>> findByItem(
    int itemId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db.query(
      tableName,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'event_date DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Event.fromMap).toList();
  }

  @override
  Future<Event?> findLatestByItem(int itemId) async {
    final rows = await _db.query(
      tableName,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'event_date DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Event.fromMap(rows.first);
  }

  @override
  Future<List<Event>> findByType(String type, {int limit = 100}) async {
    final rows = await _db.query(
      tableName,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'event_date DESC',
      limit: limit,
    );
    return rows.map(Event.fromMap).toList();
  }
}