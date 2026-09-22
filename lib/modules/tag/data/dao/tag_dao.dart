/// 模块：tag / data / dao
/// 职责：tag 表 + item_tag 关联表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/tag.dart';
import '../../domain/ports/tag_repo.dart';

class TagDao implements TagRepo {
  static const String tableName = 'tag';
  static const String linkTable = 'item_tag';

  final Database _db;
  TagDao(this._db);

  @override
  Future<List<Tag>> findAll() async {
    final rows = await _db.query(tableName, orderBy: 'name ASC');
    return rows.map(Tag.fromMap).toList();
  }

  @override
  Future<Tag?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Tag.fromMap(rows.first);
  }

  @override
  Future<int> insert(Tag tag) async {
    try {
      return await _db.insert(tableName, tag.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('新增标签失败', cause: e);
    }
  }

  @override
  Future<void> update(Tag tag) async {
    if (tag.id == null) {
      throw const ValidationException('更新标签时 id 不能为空');
    }
    await _db.update(
      tableName,
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    // 先删关联，再删标签本身。
    await _db.delete(linkTable, where: 'tag_id = ?', whereArgs: [id]);
    await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Tag>> findByItem(int itemId) async {
    final rows = await _db.rawQuery(
      'SELECT t.* FROM $tableName t '
      'INNER JOIN $linkTable it ON t.id = it.tag_id '
      'WHERE it.item_id = ? '
      'ORDER BY t.name ASC',
      [itemId],
    );
    return rows.map(Tag.fromMap).toList();
  }

  @override
  Future<void> linkItem({required int tagId, required int itemId}) async {
    try {
      await _db.insert(
        linkTable,
        {'tag_id': tagId, 'item_id': itemId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('建立标签关联失败', cause: e);
    }
  }

  @override
  Future<void> unlinkItem({required int tagId, required int itemId}) async {
    await _db.delete(
      linkTable,
      where: 'tag_id = ? AND item_id = ?',
      whereArgs: [tagId, itemId],
    );
  }

  @override
  Future<void> unlinkAllByItem(int itemId) async {
    await _db.delete(linkTable, where: 'item_id = ?', whereArgs: [itemId]);
  }

  @override
  Future<int> countItemsByTag(int tagId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $linkTable WHERE tag_id = ?',
      [tagId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}