/// 模块：suggestion / domain / ports
/// 职责：suggestion 模块对外契约。
library;

import '../../../item/domain/ports/item_port.dart' show ItemBrief;
import '../entities/candidate.dart';
import '../entities/candidate_group.dart';

class SuggestionResult {
  final List<ItemBrief> items;
  final List<Candidate> candidates;

  const SuggestionResult({
    required this.items,
    required this.candidates,
  });

  static const SuggestionResult empty =
      SuggestionResult(items: [], candidates: []);

  bool get isEmpty => items.isEmpty && candidates.isEmpty;
}

class CandidateStats {
  final int total;
  final int recorded;
  final int unrecorded;
  const CandidateStats({
    required this.total,
    required this.recorded,
    required this.unrecorded,
  });
}

/// 导入结果。
class ImportResult {
  final int added;
  final int skipped;
  final int invalid;
  const ImportResult({
    required this.added,
    required this.skipped,
    required this.invalid,
  });
}

abstract class SuggestionPort {
  Future<SuggestionResult> suggest({
    required String keyword,
    int limit = 30,
  });

  Future<void> adopt({required int candidateId, required int itemId});
  Future<void> incrementHit(int candidateId);
  Future<List<ItemBrief>> listLinkedItems(int candidateId);
  Future<void> unlink({required int candidateId, required int itemId});
  Future<int> countLinked(int candidateId);
  Future<Map<int, int>> countLinkedBatch(List<int> candidateIds);

  /// 添加候选词。[group] 为空时归入 'other'。
  Future<void> addCandidate(String word, {String? group});

  Future<void> updateWord({required int candidateId, required String newWord});

  /// 修改大类。
  Future<void> updateGroup({
    required int candidateId,
    required String group,
  });

  /// 批量修改大类。
  Future<void> bulkUpdateGroup({
    required List<int> ids,
    required String group,
  });

  /// 批量删除候选词及其关联。
  Future<void> bulkDelete(List<int> ids);

  Future<void> delete(int candidateId);

  /// 列出候选词。
  Future<List<Candidate>> listAll({
    String orderBy = 'weight',
    String filter = 'all',
    String? group,
  });

  /// 批量导入词条（每行一个词）。
  ///
  /// [words] 原始词条列表，会做 trim 和归一化。
  /// [group] 归入的大类。
  /// 返回统计。
  Future<ImportResult> importWords({
    required List<String> words,
    required String group,
  });

  /// 导出词条为纯文本（每行一个）。
  ///
  /// [group] 为 null 时导出所有。
  /// [onlyUserAdded] 为 true 时只导出 source='user' 的词条。
  Future<List<String>> exportWords({
    String? group,
    bool onlyUserAdded = false,
  });

  /// 导出为 Dart 源码字符串。
  ///
  /// [group] 指定大类。生成的代码可以直接粘贴到
  /// `lib/modules/suggestion/data/words/{group}.dart`。
  Future<String> exportAsDart(String group);

  /// 每个大类的词条数量。
  Future<Map<String, int>> countByGroup();

  Future<CandidateStats> stats();

  // ---------- 大类管理 ----------

  /// 列出所有大类。至少包含 'other'。
  Future<List<CandidateGroup>> listGroups();

  /// 新建自定义大类。
  ///
  /// [key] 内部标识，仅允许小写字母和数字，全局唯一。
  /// [label] 显示名。
  /// 抛出 [ValidationException] 当 key 非法或已存在。
  Future<void> createGroup({required String key, required String label});

  /// 重命名大类。
  ///
  /// 'other' 禁止重命名，抛 [ValidationException]。
  Future<void> renameGroup({required String key, required String newLabel});

  /// 删除大类。
  ///
  /// 'other' 禁止删除，抛 [ValidationException]。
  /// 该大类下所有候选词的 group_name 会被改为 'other'。
  Future<void> deleteGroup(String key);

  // ---------- 学习机制 ----------

  /// 精确查询词库中是否存在同名候选词。
  ///
  /// 返回可能多个（同 normalized 不同大类）。
  /// 用于物品保存后询问用户"是否与现有词条指代相同"。
  Future<List<Candidate>> findByExactName(String word);

  /// 从物品学习：建立候选词与物品的关联并增加权重。
  ///
  /// [existingCandidateId] 有值时：直接关联到该候选词。
  /// [existingCandidateId] 为 null 时：先创建候选词（归入 [group]），再关联。
  ///
  /// 副作用：新增 candidate（可选）、写 candidate_item 关联、hit_count +1。
  Future<void> learnFromItem({
    required int itemId,
    required String word,
    String? group,
    int? existingCandidateId,
  });
}