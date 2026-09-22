/// 模块：suggestion / domain / ports
/// 职责：候选词-物品多对多关联契约。
/// 约束：
///   1. 一个候选词可关联多个物品（如"台灯"关联客厅台灯 + 卧室台灯）。
///   2. 一个物品也可关联多个候选词（别名场景）。
library;

abstract class CandidateItemRepo {
  /// 查询候选词关联的所有物品 id，按关联时间降序。
  Future<List<int>> findItemIdsByCandidate(int candidateId);

  /// 建立关联。已存在则忽略（唯一索引兜底）。
  Future<void> link({required int candidateId, required int itemId});

  /// 解除关联。
  Future<void> unlink({required int candidateId, required int itemId});

  /// 候选词的关联数量。
  Future<int> countByCandidate(int candidateId);

  /// 批量为多个候选词统计关联数。
  ///
  /// 用于词库管理页一次性拉取所有候选词的关联数，避免 N+1 查询。
  Future<Map<int, int>> countByCandidates(List<int> candidateIds);
}