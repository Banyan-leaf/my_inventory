/// 模块：suggestion / data / dao
/// 职责：candidate 表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/ports/candidate_repo.dart';

class CandidateDao implements CandidateRepo {
  static const String tableName = 'candidate';

  final Database _db;
  CandidateDao(this._db);

  @override
  Future<Candidate?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Candidate.fromMap(rows.first);
  }

  @override
  Future<List<Candidate>> search(
    String keyword, {
    String? group,
    int limit = 50,
  }) async {
    final norm = keyword.trim().toLowerCase();
    if (norm.isEmpty) return const [];

    final where = <String>['normalized LIKE ?'];
    final args = <Object?>['%$norm%'];
    if (group != null) {
      where.add('group_name = ?');
      args.add(group);
    }

    final rows = await _db.query(
      tableName,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: 'hit_count DESC, item_id IS NULL ASC, id ASC',
      limit: limit,
    );
    return rows.map(Candidate.fromMap).toList();
  }

  @override
  Future<List<Candidate>> listAll({
    String orderBy = 'weight',
    String filter = 'all',
    String? group,
    int limit = 100000,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    switch (filter) {
      case 'recorded':
        where.add('item_id IS NOT NULL');
        break;
      case 'unrecorded':
        where.add('item_id IS NULL');
        break;
    }
    if (group != null) {
      where.add('group_name = ?');
      args.add(group);
    }
    final order = switch (orderBy) {
      'name' => 'word ASC',
      _ => 'hit_count DESC, item_id IS NULL ASC, id ASC',
    };

    final rows = await _db.query(
      tableName,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: order,
      limit: limit,
    );
    return rows.map(Candidate.fromMap).toList();
  }

  @override
  Future<int> insert(Candidate candidate) async {
    try {
      return await _db.insert(
        tableName,
        candidate.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      throw AppDatabaseException('写入候选词失败', cause: e);
    }
  }

  @override
  Future<void> bulkInsert(List<Candidate> candidates) async {
    final batch = _db.batch();
    for (final c in candidates) {
      batch.insert(
        tableName,
        c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updateWord(
    int id,
    String newWord,
    String newNormalized,
  ) async {
    await _db.update(
      tableName,
      {'word': newWord, 'normalized': newNormalized},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> updateGroup(int id, String group) async {
    await _db.update(
      tableName,
      {'group_name': group},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> bulkUpdateGroup(List<int> ids, String group) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE $tableName SET group_name = ? WHERE id IN ($placeholders)',
      [group, ...ids],
    );
  }

  @override
  Future<void> bulkDelete(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawDelete(
      'DELETE FROM $tableName WHERE id IN ($placeholders)',
      ids,
    );
  }

  @override
  Future<void> linkOrIncrement(int id, int itemId) async {
    await _db.rawUpdate(
      'UPDATE $tableName SET '
      'item_id = COALESCE(item_id, ?), '
      'hit_count = hit_count + 1 '
      'WHERE id = ?',
      [itemId, id],
    );
  }

  @override
  Future<void> incrementHit(int id) async {
    await _db.rawUpdate(
      'UPDATE $tableName SET hit_count = hit_count + 1 WHERE id = ?',
      [id],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, int>> countByGroup() async {
    final rows = await _db.rawQuery(
      'SELECT group_name, COUNT(*) AS c FROM $tableName GROUP BY group_name',
    );
    return {
      for (final r in rows)
        (r['group_name'] as String): (r['c'] as int?) ?? 0,
    };
  }

  @override
  Future<int> countBySource(String source) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableName WHERE source = ?',
      [source],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> countRecorded() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $tableName WHERE item_id IS NOT NULL',
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<Candidate>> findByExactName(String word) async {
    final norm = word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (norm.isEmpty) return const [];
    final rows = await _db.query(
      tableName,
      where: 'normalized = ?',
      whereArgs: [norm],
      orderBy: 'hit_count DESC, id ASC',
    );
    return rows.map(Candidate.fromMap).toList();
  }
}