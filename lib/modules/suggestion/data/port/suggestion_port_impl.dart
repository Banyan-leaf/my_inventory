/// 模块：suggestion / data / port
/// 职责：SuggestionPort 的实现。
library;

import '../../../../core/di/port_registry.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../item/domain/ports/item_port.dart';
import '../../domain/entities/candidate.dart';
import '../../domain/entities/candidate_group.dart';
import '../../domain/ports/candidate_group_repo.dart';
import '../../domain/ports/candidate_item_repo.dart';
import '../../domain/ports/candidate_repo.dart';
import '../../domain/ports/suggestion_port.dart';
import '../builtin_words.dart';

class SuggestionPortImpl implements SuggestionPort {
  final CandidateRepo _repo;
  final CandidateItemRepo _linkRepo;
  final CandidateGroupRepo _groupRepo;

  SuggestionPortImpl(this._repo, this._linkRepo, this._groupRepo);

  ItemPort get _itemPort => PortRegistry.instance.resolve<ItemPort>();

  static String normalize(String word) =>
      word.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');

  /// 幂等同步内置大类到数据库。
  ///
  /// 首次运行时插入所有内置大类。
  /// 'other' 强制标 is_system=true。
  /// 用户重命名过的内置大类，label 保留用户版本。
  Future<void> seedGroupsIfNeeded() async {
    final builtinKeys = CandidateGroups.builtinCategories;
    var order = 0;

    // 1. 内置大类
    for (final key in builtinKeys) {
      final existing = await _groupRepo.findByKey(key);
      if (existing == null) {
        await _groupRepo.insert(CandidateGroup(
          key: key,
          label: CandidateGroups.labelOf(key),
          isSystem: false,
          sortOrder: order,
        ));
      }
      order++;
    }

    // 2. 'other' 兜底大类（system，永远存在）
    final other = await _groupRepo.findByKey(CandidateGroups.otherKey);
    if (other == null) {
      await _groupRepo.insert(const CandidateGroup(
        key: CandidateGroups.otherKey,
        label: '其他',
        isSystem: true,
        sortOrder: 9999,
      ));
    } else if (!other.isSystem) {
      // 修正历史数据
      await _groupRepo.delete(CandidateGroups.otherKey);
      await _groupRepo.insert(const CandidateGroup(
        key: CandidateGroups.otherKey,
        label: '其他',
        isSystem: true,
        sortOrder: 9999,
      ));
    }

    final all = await _groupRepo.findAll();
    AppLogger.info('Suggestion', '大类就绪（${all.length} 个）');
  }

  /// 幂等同步内置词库。
  ///
  /// 若某内置大类已被用户删除，该大类的词条将落入 'other'。
  Future<void> seedBuiltinIfNeeded() async {
    var totalCount = 0;
    final existingKeys = (await _groupRepo.findAll()).map((g) => g.key).toSet();

    for (final entry in builtinWordsByGroup.entries) {
      final groupKey = entry.key;
      final words = entry.value;
      if (words.isEmpty) continue;

      // 大类被删则词条落到 other
      final effectiveGroup =
          existingKeys.contains(groupKey) ? groupKey : CandidateGroups.otherKey;

      final candidates = words
          .map((w) => Candidate(
                word: w,
                normalized: normalize(w),
                source: Candidate.sourceBuiltin,
                groupName: effectiveGroup,
              ))
          .toList();
      await _repo.bulkInsert(candidates);
      totalCount += words.length;
    }

    final builtinTotal = await _repo.countBySource(Candidate.sourceBuiltin);
    final added = totalCount - builtinTotal;
    if (added > 0) {
      AppLogger.info(
        'Suggestion',
        '内置词库同步：列表 $totalCount 条，库内 $builtinTotal 条，新增 $added 条',
      );
    } else {
      AppLogger.info('Suggestion', '内置词库已同步（$builtinTotal 条，无新增）');
    }
  }

  @override
  Future<SuggestionResult> suggest({
    required String keyword,
    int limit = 30,
  }) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return SuggestionResult.empty;

    final results = await Future.wait([
      _itemPort.listBriefs(query: ItemQuery(keyword: kw)),
      _repo.search(kw, limit: limit),
    ]);

    final items = results[0] as List<ItemBrief>;
    final candidates = results[1] as List<Candidate>;

    return SuggestionResult(
      items: items.take(limit).toList(),
      candidates: candidates,
    );
  }

  @override
  Future<void> adopt({
    required int candidateId,
    required int itemId,
  }) async {
    final c = await _repo.findById(candidateId);
    if (c == null) {
      throw NotFoundException('候选词 $candidateId 不存在');
    }
    await _linkRepo.link(candidateId: candidateId, itemId: itemId);
    await _repo.linkOrIncrement(candidateId, itemId);
  }

  @override
  Future<void> incrementHit(int candidateId) async {
    final c = await _repo.findById(candidateId);
    if (c == null) {
      throw NotFoundException('候选词 $candidateId 不存在');
    }
    await _repo.incrementHit(candidateId);
  }

  @override
  Future<List<ItemBrief>> listLinkedItems(int candidateId) async {
    final itemIds = await _linkRepo.findItemIdsByCandidate(candidateId);
    if (itemIds.isEmpty) return const [];

    final results = <ItemBrief>[];
    for (final id in itemIds) {
      final item = await _itemPort.findById(id);
      if (item == null) continue;
      results.add(ItemBrief(
        id: item.id!,
        name: item.name,
        locationId: item.locationId,
        categoryId: item.categoryId,
        status: item.status,
      ));
    }
    return results;
  }

  @override
  Future<void> unlink({
    required int candidateId,
    required int itemId,
  }) =>
      _linkRepo.unlink(candidateId: candidateId, itemId: itemId);

  @override
  Future<int> countLinked(int candidateId) =>
      _linkRepo.countByCandidate(candidateId);

  @override
  Future<Map<int, int>> countLinkedBatch(List<int> candidateIds) =>
      _linkRepo.countByCandidates(candidateIds);

  @override
  Future<void> addCandidate(String word, {String? group}) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('候选词不能为空');
    }
    final groupKey = group ?? CandidateGroups.otherKey;
    // 大类不存在则落 other
    final exists = await _groupRepo.exists(groupKey);
    await _repo.insert(Candidate(
      word: trimmed,
      normalized: normalize(trimmed),
      source: Candidate.sourceUser,
      groupName: exists ? groupKey : CandidateGroups.otherKey,
    ));
  }

  @override
  Future<void> updateWord({
    required int candidateId,
    required String newWord,
  }) async {
    final trimmed = newWord.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('候选词不能为空');
    }
    final c = await _repo.findById(candidateId);
    if (c == null) {
      throw NotFoundException('候选词 $candidateId 不存在');
    }
    await _repo.updateWord(candidateId, trimmed, normalize(trimmed));
  }

  @override
  Future<void> updateGroup({
    required int candidateId,
    required String group,
  }) async {
    final exists = await _groupRepo.exists(group);
    if (!exists) {
      throw ValidationException('大类 $group 不存在');
    }
    await _repo.updateGroup(candidateId, group);
  }

  @override
  Future<void> bulkUpdateGroup({
    required List<int> ids,
    required String group,
  }) async {
    final exists = await _groupRepo.exists(group);
    if (!exists) {
      throw ValidationException('大类 $group 不存在');
    }
    await _repo.bulkUpdateGroup(ids, group);
  }

  @override
  Future<void> bulkDelete(List<int> ids) async {
    for (final id in ids) {
      final itemIds = await _linkRepo.findItemIdsByCandidate(id);
      for (final itemId in itemIds) {
        await _linkRepo.unlink(candidateId: id, itemId: itemId);
      }
    }
    await _repo.bulkDelete(ids);
  }

  @override
  Future<void> delete(int candidateId) async {
    final ids = await _linkRepo.findItemIdsByCandidate(candidateId);
    for (final id in ids) {
      await _linkRepo.unlink(candidateId: candidateId, itemId: id);
    }
    await _repo.delete(candidateId);
  }

  @override
  Future<List<Candidate>> listAll({
    String orderBy = 'weight',
    String filter = 'all',
    String? group,
  }) =>
      _repo.listAll(orderBy: orderBy, filter: filter, group: group);

  @override
  Future<ImportResult> importWords({
    required List<String> words,
    required String group,
  }) async {
    var added = 0;
    var skipped = 0;
    var invalid = 0;

    final exists = await _groupRepo.exists(group);
    final effectiveGroup =
        exists ? group : CandidateGroups.otherKey;

    final cleaned = <Candidate>[];
    for (final raw in words) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        invalid++;
        continue;
      }
      cleaned.add(Candidate(
        word: trimmed,
        normalized: normalize(trimmed),
        source: Candidate.sourceUser,
        groupName: effectiveGroup,
      ));
    }

    final existing = await _repo.listAll(limit: 100000);
    final existingNorm = existing.map((c) => c.normalized).toSet();

    final toInsert = <Candidate>[];
    for (final c in cleaned) {
      if (existingNorm.contains(c.normalized)) {
        skipped++;
      } else {
        toInsert.add(c);
        added++;
      }
    }

    if (toInsert.isNotEmpty) {
      await _repo.bulkInsert(toInsert);
    }

    return ImportResult(added: added, skipped: skipped, invalid: invalid);
  }

  @override
  Future<List<String>> exportWords({
    String? group,
    bool onlyUserAdded = false,
  }) async {
    final all = await _repo.listAll(
      orderBy: 'name',
      group: group,
      limit: 100000,
    );
    if (!onlyUserAdded) {
      return all.map((c) => c.word).toList();
    }
    return all
        .where((c) => c.source == Candidate.sourceUser)
        .map((c) => c.word)
        .toList()
      ..sort();
  }

  @override
  Future<String> exportAsDart(String group) async {
    final words = await _repo.listAll(
      orderBy: 'name',
      group: group,
      limit: 100000,
    );

    final groupMeta = await _groupRepo.findByKey(group);
    final label = groupMeta?.label ?? group;
    final varName = _dartVarName(group);
    final fileName = '$group.dart';

    final buf = StringBuffer();
    buf.writeln('/// 模块：suggestion / data / words / $group');
    buf.writeln('/// 职责：$label类物品词库。');
    buf.writeln('/// 生成时间：${DateTime.now().toIso8601String()}');
    buf.writeln('library;');
    buf.writeln();
    buf.writeln('const List<String> $varName = [');
    for (final c in words) {
      final escaped = c.word.replaceAll("'", r"\'");
      buf.writeln("  '$escaped',");
    }
    buf.writeln('];');
    buf.writeln();
    buf.writeln('// 保存路径: lib/modules/suggestion/data/words/$fileName');
    return buf.toString();
  }

  String _dartVarName(String group) {
    if (group.isEmpty) return 'wordsOther';
    return 'words${group[0].toUpperCase()}${group.substring(1)}';
  }

  @override
  Future<Map<String, int>> countByGroup() => _repo.countByGroup();

  @override
  Future<CandidateStats> stats() async {
    final total = await _repo.countBySource(Candidate.sourceBuiltin) +
        await _repo.countBySource(Candidate.sourceUser) +
        await _repo.countBySource(Candidate.sourceExtracted);
    final recorded = await _repo.countRecorded();
    return CandidateStats(
      total: total,
      recorded: recorded,
      unrecorded: total - recorded,
    );
  }

  // ---------- 大类管理 ----------

  @override
  Future<List<CandidateGroup>> listGroups() => _groupRepo.findAll();

  @override
  Future<void> createGroup({
    required String key,
    required String label,
  }) async {
    final k = key.trim().toLowerCase();
    final l = label.trim();

    if (!RegExp(r'^[a-z][a-z0-9_]{0,30}$').hasMatch(k)) {
      throw const ValidationException(
        'key 只允许小写字母、数字、下划线，且以字母开头，长度 1-32',
      );
    }
    if (l.isEmpty) {
      throw const ValidationException('显示名不能为空');
    }
    if (await _groupRepo.exists(k)) {
      throw ValidationException('大类 $k 已存在');
    }

    await _groupRepo.insert(CandidateGroup(
      key: k,
      label: l,
      isSystem: false,
      sortOrder: 1000,
    ));
  }

  @override
  Future<void> renameGroup({
    required String key,
    required String newLabel,
  }) async {
    if (key == CandidateGroups.otherKey) {
      throw const ValidationException('"其他"大类不可重命名');
    }
    final g = await _groupRepo.findByKey(key);
    if (g == null) {
      throw NotFoundException('大类 $key 不存在');
    }
    final trimmed = newLabel.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('显示名不能为空');
    }
    await _groupRepo.updateLabel(key, trimmed);
  }

  @override
  Future<void> deleteGroup(String key) async {
    if (key == CandidateGroups.otherKey) {
      throw const ValidationException('"其他"大类不可删除');
    }
    final g = await _groupRepo.findByKey(key);
    if (g == null) {
      throw NotFoundException('大类 $key 不存在');
    }

    // 1. 该大类下所有候选词的 group_name 改为 'other'
    final candidates = await _repo.listAll(group: key, limit: 100000);
    if (candidates.isNotEmpty) {
      final ids = candidates.map((c) => c.id!).toList();
      await _repo.bulkUpdateGroup(ids, CandidateGroups.otherKey);
    }

    // 2. 删除大类
    await _groupRepo.delete(key);
  }

  // ---------- 学习机制 ----------

  @override
  Future<List<Candidate>> findByExactName(String word) =>
      _repo.findByExactName(word);

  @override
  Future<void> learnFromItem({
    required int itemId,
    required String word,
    String? group,
    int? existingCandidateId,
  }) async {
    int candidateId;

    if (existingCandidateId != null) {
      // 场景 B：用户选了一个现有词条
      final c = await _repo.findById(existingCandidateId);
      if (c == null) {
        throw NotFoundException('候选词 $existingCandidateId 不存在');
      }
      candidateId = existingCandidateId;
    } else {
      // 场景 A：创建新词条
      final trimmed = word.trim();
      if (trimmed.isEmpty) {
        throw const ValidationException('词条名称不能为空');
      }
      final groupKey = group ?? CandidateGroups.otherKey;
      final exists = await _groupRepo.exists(groupKey);

      final newId = await _repo.insert(Candidate(
        word: trimmed,
        normalized: normalize(trimmed),
        source: Candidate.sourceUser,
        groupName: exists ? groupKey : CandidateGroups.otherKey,
      ));

      if (newId == 0) {
        // 唯一索引冲突，查一下已存在的
        final matches = await _repo.findByExactName(trimmed);
        if (matches.isEmpty) {
          throw const ValidationException('创建候选词失败');
        }
        candidateId = matches.first.id!;
      } else {
        candidateId = newId;
      }
    }

    // 关联 + 权重 +1
    await _linkRepo.link(candidateId: candidateId, itemId: itemId);
    await _repo.linkOrIncrement(candidateId, itemId);
  }
}