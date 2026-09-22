/// 模块：app / pages / group_manage
/// 职责：候选词大类管理。
/// 功能：新增、重命名、删除大类。
/// 约束：
///   - 'other' 禁止重命名和删除（由 SuggestionPort 兜底）。
///   - 删除大类时该大类下词条自动迁移到 'other'。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/suggestion/domain/entities/candidate.dart';
import '../../modules/suggestion/domain/entities/candidate_group.dart';
import '../../modules/suggestion/domain/ports/suggestion_port.dart';

class GroupManagePage extends StatefulWidget {
  const GroupManagePage({super.key});

  @override
  State<GroupManagePage> createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  List<CandidateGroup> _groups = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;

  SuggestionPort get _port => PortRegistry.instance.resolve<SuggestionPort>();

  @override
  void initState() {
    super.initState();
    AppRefresh.instance.addListener(_onRefresh);
    _load();
  }

  @override
  void dispose() {
    AppRefresh.instance.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final groups = await _port.listGroups();
    final counts = await _port.countByGroup();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final result = await _promptNewGroup();
    if (result == null) return;
    try {
      await _port.createGroup(key: result.key, label: result.label);
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败：${e.message}')));
    }
  }

  Future<void> _rename(CandidateGroup g) async {
    final newLabel = await _promptText('重命名大类', initial: g.label);
    if (newLabel == null || newLabel.trim().isEmpty) return;
    try {
      await _port.renameGroup(key: g.key, newLabel: newLabel.trim());
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('重命名失败：${e.message}')));
    }
  }

  Future<void> _delete(CandidateGroup g) async {
    final count = _counts[g.key] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除大类'),
        content: Text(
          count == 0
              ? '确定删除"${g.label}"吗？'
              : '确定删除"${g.label}"吗？\n\n该大类下 $count 条词条将自动迁移到"其他"。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _port.deleteGroup(g.key);
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：${e.message}')));
    }
  }

  Future<String?> _promptText(String title, {String? initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '显示名'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<({String key, String label})?> _promptNewGroup() async {
    final keyCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    return showDialog<({String key, String label})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建大类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '显示名（如：乐器）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: '内部标识（如：music）',
                helperText: '小写字母 / 数字 / 下划线',
                helperStyle: TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final k = keyCtrl.text.trim();
              final l = labelCtrl.text.trim();
              if (k.isEmpty || l.isEmpty) return;
              Navigator.pop(ctx, (key: k, label: l));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大类管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _groups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final g = _groups[i];
                final count = _counts[g.key] ?? 0;
                final isOther = g.key == CandidateGroups.otherKey;
                return ListTile(
                  leading: Icon(
                    isOther ? Icons.inbox : Icons.category_outlined,
                    color: isOther ? Colors.orange : Colors.teal,
                  ),
                  title: Text(g.label),
                  subtitle: Text(
                    '${g.key} · $count 条'
                    '${isOther ? ' · 系统保留' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: isOther
                      ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _rename(g),
                              tooltip: '重命名',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _delete(g),
                              tooltip: '删除',
                            ),
                          ],
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: '新建大类',
        child: const Icon(Icons.add),
      ),
    );
  }
}