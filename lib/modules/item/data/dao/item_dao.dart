/// 模块：item / data / dao
/// 职责：item 表的 SQL 操作。
/// 约束：只做 CRUD 与 WHERE 拼装，不做外键校验。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/item.dart';
import '../../domain/ports/item_port.dart' show ItemQuery;
import '../../domain/ports/item_repo.dart';

class ItemDao implements ItemRepo {
  static const String tableName = 'item';

  final Database _db;
  ItemDao(this._db);

  @override
  Future<Item?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  @override
  Future<List<Item>> search(ItemQuery query) async {
    final where = <String>[];
    final args = <Object?>[];

    if (!query.includeDeleted) {
      where.add('deleted_at IS NULL');
    }
    if (query.keyword != null && query.keyword!.trim().isNotEmpty) {
      where.add('(name LIKE ? OR aliases LIKE ?)');
      final kw = '%${query.keyword!.trim()}%';
      args.add(kw);
      args.add(kw);
    }
    if (query.locationId != null) {
      where.add('location_id = ?');
      args.add(query.locationId);
    }
    if (query.categoryId != null) {
      where.add('category_id = ?');
      args.add(query.categoryId);
    }
    if (query.status != null) {
      where.add('status = ?');
      args.add(query.status);
    }

    final rows = await _db.query(
      tableName,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Item.fromMap).toList();
  }

  @override
  Future<int> insert(Item item) async {
    try {
      return await _db.insert(tableName, item.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('新增物品失败', cause: e);
    }
  }

  @override
  Future<void> update(Item item) async {
    if (item.id == null) {
      throw const ValidationException('更新物品时 id 不能为空');
    }
    final map = item.toMap();
    map['updated_at'] = DateTime.now().toIso8601String();
    await _db.update(
      tableName,
      map,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> softDelete(int id, DateTime deletedAt) async {
    await _db.update(
      tableName,
      {
        'deleted_at': deletedAt.toIso8601String(),
        'updated_at': deletedAt.toIso8601String(),
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  @override
  Future<void> bulkUpdateStatus(List<int> ids, String status) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE $tableName SET status = ?, updated_at = ? '
      'WHERE id IN ($placeholders) AND deleted_at IS NULL',
      [status, DateTime.now().toIso8601String(), ...ids],
    );
  }
}