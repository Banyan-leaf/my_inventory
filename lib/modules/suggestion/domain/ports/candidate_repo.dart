/// 模块：suggestion / domain / ports
/// 职责：候选词仓储契约。
library;

import '../entities/candidate.dart';

abstract class CandidateRepo {
  Future<Candidate?> findById(int id);

  /// 关键词搜索。group 为 null 时不过滤大类。
  Future<List<Candidate>> search(
    String keyword, {
    String? group,
    int limit = 50,
  });

  /// 列出候选词。
  ///
  /// [orderBy] weight / name
  /// [filter]  all / recorded / unrecorded
  /// [group]   null 表示不过滤
  Future<List<Candidate>> listAll({
    String orderBy = 'weight',
    String filter = 'all',
    String? group,
    int limit = 2000,
  });

  Future<int> insert(Candidate candidate);

  Future<void> bulkInsert(List<Candidate> candidates);

  /// 更新词条文本。
  Future<void> updateWord(int id, String newWord, String newNormalized);

  /// 更新大类。
  Future<void> updateGroup(int id, String group);

  /// 批量更新大类。
  Future<void> bulkUpdateGroup(List<int> ids, String group);

  /// 批量删除。
  Future<void> bulkDelete(List<int> ids);

  Future<void> linkOrIncrement(int id, int itemId);
  Future<void> incrementHit(int id);
  Future<void> delete(int id);

  /// 按大类统计数量。
  Future<Map<String, int>> countByGroup();

  Future<int> countBySource(String source);
  Future<int> countRecorded();

  /// 精确查询同名候选词（归一化后完全匹配）。
  ///
  /// 用于学习机制：判断某个物品名是否已在词库中存在。
  /// 可能返回多个（同 normalized 不同 group）。
  Future<List<Candidate>> findByExactName(String word);
}