/// 模块：app / pages / widgets
/// 职责：物品保存后的"学习到词库"对话框。
/// 约束：
///   1. 场景 A（无同名）：直接问是否加入词库 + 选大类。
///   2. 场景 B（有同名）：列出所有同名候选，用户选指代哪一个或创建新的。
///   3. 不再弹"小提示"，改为在设置页提供"新手指引"入口。
library;

import 'package:flutter/material.dart';

import '../../../core/di/port_registry.dart';
import '../../../core/error/app_exception.dart';
import '../../../modules/suggestion/domain/entities/candidate.dart';
import '../../../modules/suggestion/domain/ports/suggestion_port.dart';

/// 展示学习对话框。返回 true 表示已加入词库，false/null 表示跳过。
Future<bool?> showLearnDialog(
  BuildContext context, {
  required int itemId,
  required String itemName,
}) async {
  final port = PortRegistry.instance.resolve<SuggestionPort>();
  final matches = await port.findByExactName(itemName);
  if (!context.mounted) return null;

  bool? added;
  if (matches.isEmpty) {
    added = await _showCreateDialog(context, port, itemId, itemName);
  } else {
    added = await _showMatchDialog(context, port, itemId, itemName, matches);
  }
  return added;
}

/// 场景 A：无同名，直接创建。
Future<bool?> _showCreateDialog(
  BuildContext context,
  SuggestionPort port,
  int itemId,
  String itemName,
) async {
  final groups = await port.listGroups();
  if (!context.mounted) return null;

  String selectedGroup = groups.any((g) => g.key == CandidateGroups.otherKey)
      ? CandidateGroups.otherKey
      : (groups.isEmpty ? CandidateGroups.otherKey : groups.first.key);

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.library_add_outlined, color: Colors.teal),
            SizedBox(width: 8),
            Text('加入词库'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('把「$itemName」加入联想词库？'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedGroup,
              decoration: const InputDecoration(
                labelText: '归入大类',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final g in groups)
                  DropdownMenuItem(value: g.key, child: Text(g.label)),
              ],
              onChanged: (v) =>
                  setDialogState(() => selectedGroup = v ?? selectedGroup),
            ),
            const SizedBox(height: 8),
            const Text(
              '加入后，下次输入相同关键词时会更快找到这个词条。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await port.learnFromItem(
                  itemId: itemId,
                  word: itemName,
                  group: selectedGroup,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, true);
              } on AppException catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('加入失败：${e.message}')),
                );
              }
            },
            child: const Text('加入并关联'),
          ),
        ],
      ),
    ),
  );
}

/// 场景 B：有同名，让用户选指代哪个。
Future<bool?> _showMatchDialog(
  BuildContext context,
  SuggestionPort port,
  int itemId,
  String itemName,
  List<Candidate> matches,
) async {
  int selectedId = matches.first.id!;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '词库中已有「$itemName」',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '你录入的「$itemName」和哪个指代相同？',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (final m in matches)
                _MatchTile(
                  candidate: m,
                  selected: selectedId == m.id,
                  onTap: () => setDialogState(() => selectedId = m.id!),
                ),
              const Divider(height: 16),
              InkWell(
                onTap: () => setDialogState(() => selectedId = -1),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      Icon(
                        selectedId == -1
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color:
                            selectedId == -1 ? Colors.teal : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '都不是，创建新词条',
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '归入一个新的大类',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                if (selectedId == -1) {
                  final added = await _showCreateDialog(
                    ctx,
                    port,
                    itemId,
                    itemName,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, added);
                } else {
                  await port.learnFromItem(
                    itemId: itemId,
                    word: itemName,
                    existingCandidateId: selectedId,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                }
              } on AppException catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('操作失败：${e.message}')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    ),
  );
}

class _MatchTile extends StatelessWidget {
  final Candidate candidate;
  final bool selected;
  final VoidCallback onTap;

  const _MatchTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final groupLabel = CandidateGroups.labelOf(candidate.groupName);
    return Card(
      elevation: 0,
      color: selected
          ? Colors.teal.withValues(alpha: 0.08)
          : Colors.grey.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? Colors.teal.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? Colors.teal : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${candidate.word} · $groupLabel',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '权重 ${candidate.hitCount}'
                      '${candidate.isRecorded ? ' · 已关联物品' : ' · 未关联'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}