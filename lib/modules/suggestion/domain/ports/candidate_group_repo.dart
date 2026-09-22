/// 模块：suggestion / domain / ports
/// 职责：候选词大类仓储契约。
library;

import '../entities/candidate_group.dart';

abstract class CandidateGroupRepo {
  /// 列出所有大类，按 sort_order, label 排序。
  Future<List<CandidateGroup>> findAll();

  /// 按 key 查。不存在返回 null。
  Future<CandidateGroup?> findByKey(String key);

  /// 插入。key 已存在则忽略。
  Future<void> insert(CandidateGroup group);

  /// 更新 label。
  Future<void> updateLabel(String key, String newLabel);

  /// 删除。
  Future<void> delete(String key);

  /// 大类是否存在。
  Future<bool> exists(String key);
}