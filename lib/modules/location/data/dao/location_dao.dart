/// 模块：location / data / dao
/// 职责：location 表的 SQL 直接操作，实现 LocationRepo 契约。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/location.dart';
import '../../domain/ports/location_repo.dart';

class LocationDao implements LocationRepo {
  static const String tableName = 'location';

  final Database _db;

  LocationDao(this._db);

  @override
  Future<List<Location>> findAll() async {
    final rows = await _db.query(
      tableName,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(Location.fromMap).toList();
  }

  @override
  Future<Location?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Location.fromMap(rows.first);
  }

  @override
  Future<List<Location>> findChildren(int? parentId) async {
    final rows = await _db.query(
      tableName,
      where: parentId == null ? 'parent_id IS NULL' : 'parent_id = ?',
      whereArgs: parentId == null ? null : [parentId],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(Location.fromMap).toList();
  }

  @override
  Future<int> insert(Location location) async {
    try {
      return await _db.insert(tableName, location.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('新增位置失败', cause: e);
    }
  }

  @override
  Future<void> update(Location location) async {
    if (location.id == null) {
      throw const ValidationException('更新位置时 id 不能为空');
    }
    await _db.update(
      tableName,
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateParent(int id, int? newParentId) async {
    await _db.update(
      tableName,
      {
        'parent_id': newParentId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> bulkUpdateSortOrder(Map<int, int> idToOrder) async {
    if (idToOrder.isEmpty) return;
    await _db.transaction((txn) async {
      for (final entry in idToOrder.entries) {
        await txn.update(
          tableName,
          {
            'sort_order': entry.value,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }
}