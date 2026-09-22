/// 模块：attachment / data / dao
/// 职责：attachment 表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/attachment.dart';
import '../../domain/ports/attachment_repo.dart';

class AttachmentDao implements AttachmentRepo {
  static const String tableName = 'attachment';

  final Database _db;
  AttachmentDao(this._db);

  @override
  Future<Attachment?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Attachment.fromMap(rows.first);
  }

  @override
  Future<List<Attachment>> findByItem(int itemId) async {
    final rows = await _db.query(
      tableName,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  @override
  Future<int> insert(Attachment attachment) async {
    try {
      return await _db.insert(tableName, attachment.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('写入附件失败', cause: e);
    }
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteByItem(int itemId) async {
    await _db.delete(tableName, where: 'item_id = ?', whereArgs: [itemId]);
  }
}