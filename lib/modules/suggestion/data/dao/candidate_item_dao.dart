/// 模块：suggestion / data / dao
/// 职责：candidate_item 关联表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/ports/candidate_item_repo.dart';

class CandidateItemDao implements CandidateItemRepo {
  static const String tableName = 'candidate_item';

  final Database _db;
  CandidateItemDao(this._db);

  @override
  Future<List<int>> findItemIdsByCandidate(int candidateId) async {
    final rows = await _db.query(
      tableName,
      columns: ['item_id'],
      where: 'candidate_id = ?',
      whereArgs: [candidateId],
      orderBy: 'linked_at DESC, id DESC',
    );
    return rows.map((r) => r['item_id'] as int).toList();
  }

  @override
  Future<void> link({
    required int candidateId,
    required int itemId,
  }) async {
    try {
      await _db.insert(
        tableName,
        {'candidate_id': candidateId, 'item_id': itemId},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('建立关联失败', cause: e);
    }
  }

  @override
  Future<void> unlink({
    required int candidateId,
    required int itemId,
  }) async {
    await _db.delete(
      tableName,
      where: 'candidate_id = ? AND item_id = ?',
      whereArgs: [candidateId, itemId],
    );
  }

  @override
  Future<int> countByCandidate(int candidateId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableName WHERE candidate_id = ?',
      [candidateId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<Map<int, int>> countByCandidates(List<int> candidateIds) async {
    if (candidateIds.isEmpty) return const {};
    final placeholders = List.filled(candidateIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT candidate_id, COUNT(*) AS c FROM $tableName '
      'WHERE candidate_id IN ($placeholders) GROUP BY candidate_id',
      candidateIds,
    );
    return {
      for (final r in rows)
        r['candidate_id'] as int: (r['c'] as int?) ?? 0,
    };
  }
}