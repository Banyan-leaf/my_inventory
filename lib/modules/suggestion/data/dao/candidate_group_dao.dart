/// 模块：suggestion / data / dao
/// 职责：candidate_group 表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/candidate_group.dart';
import '../../domain/ports/candidate_group_repo.dart';

class CandidateGroupDao implements CandidateGroupRepo {
  static const String tableName = 'candidate_group';

  final Database _db;
  CandidateGroupDao(this._db);

  @override
  Future<List<CandidateGroup>> findAll() async {
    final rows = await _db.query(
      tableName,
      orderBy: 'sort_order ASC, label ASC',
    );
    return rows.map(CandidateGroup.fromMap).toList();
  }

  @override
  Future<CandidateGroup?> findByKey(String key) async {
    final rows = await _db.query(
      tableName,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CandidateGroup.fromMap(rows.first);
  }

  @override
  Future<void> insert(CandidateGroup group) async {
    try {
      await _db.insert(
        tableName,
        group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('写入大类失败', cause: e);
    }
  }

  @override
  Future<void> updateLabel(String key, String newLabel) async {
    await _db.update(
      tableName,
      {'label': newLabel},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete(tableName, where: 'key = ?', whereArgs: [key]);
  }

  @override
  Future<bool> exists(String key) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableName WHERE key = ?',
      [key],
    );
    return ((rows.first['c'] as int?) ?? 0) > 0;
  }
}