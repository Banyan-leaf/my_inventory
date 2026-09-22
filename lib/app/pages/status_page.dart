/// 模块：app / pages / status
/// 职责：状态管理页。
/// 功能：列表、新增、改名、改色、删除（系统状态仅改名改色）。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../use_cases/migrate_status_use_case.dart';
import '../../modules/status/domain/entities/item_status.dart';
import '../../modules/status/domain/ports/status_port.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key});

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  List<ItemStatus> _list = const [];
  Map<String, int> _counts = const {};
  bool _loading = true;

  StatusPort get _port => PortRegistry.instance.resolve<StatusPort>();

  static const List<String?> _palette = [
    null,
    '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5',
    '#2196F3', '#00BCD4', '#009688', '#4CAF50', '#FF9800',
    '#795548', '#607D8B',
  ];

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
    final list = await _port.all();
    final counts = <String, int>{};
    for (final s in list) {
      counts[s.key] = await _port.countItems(s.key);
    }
    if (!mounted) return;
    setState(() {
      _list = list;
      _counts = counts;
      _loading = false;
    });
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.grey;
    return Color(0xFF000000 | value);
  }

  Future<void> _add() async {
    final result = await _promptStatus(title: '新增状态');
    if (result == null) return;
    try {
      await _port.create(
        key: result.key,
        label: result.label,
        color: result.color,
      );
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败：${e.message}')));
    }
  }

  Future<void> _edit(ItemStatus s) async {
    final result = await _promptStatus(title: '编辑状态', initial: s);
    if (result == null) return;
    try {
      if (result.label != s.label) {
        await _port.rename(key: s.key, newLabel: result.label);
      }
      if (result.color != s.color) {
        await _port.updateColor(key: s.key, color: result.color);
      }
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('编辑失败：${e.message}')));
    }
  }

  Future<void> _delete(ItemStatus s) async {
    final count = _counts[s.key] ?? 0;

    if (count > 0) {
      // 有物品在用：让用户选迁移到哪个状态
      final target = await _pickMigrationTarget(s);
      if (target == null) return;

      // 迁移物品
      try {
        await _migrateItems(from: s.key, to: target);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('迁移失败：$e')));
        return;
      }
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('删除状态'),
          content: Text('确定删除"${s.label}"吗？'),
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
    }

    try {
      await _port.delete(s.key);
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：${e.message}')));
    }
  }

  /// 迁移物品到目标状态，然后删除源状态。
  Future<void> _migrateItems({
    required String from,
    required String to,
  }) async {
    // 拿到 from 状态下的所有物品 id
    final itemPort = PortRegistry.instance.resolve<ItemPort>();
    final briefs = await itemPort.listBriefs(
      query: ItemQuery(status: from),
    );

    await MigrateStatusUseCase().execute(
      from: from,
      to: to,
      itemIds: briefs.map((b) => b.id).toList(),
    );
  }

  Future<String?> _pickMigrationTarget(ItemStatus from) async {
    final candidates = _list.where((s) => s.key != from.key).toList();
    if (candidates.isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有其他状态可迁移到，请先新增一个状态')),
      );
      return null;
    }

    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '把使用"${from.label}"的物品迁移到：',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Divider(height: 1),
            for (final s in candidates)
              ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _parseColor(s.color),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(s.label),
                onTap: () => Navigator.pop(ctx, s.key),
              ),
          ],
        ),
      ),
    );
  }

  Future<({String key, String label, String? color})?> _promptStatus({
    required String title,
    ItemStatus? initial,
  }) async {
    final labelCtrl = TextEditingController(text: initial?.label ?? '');
    final keyCtrl = TextEditingController(text: initial?.key ?? '');
    String? color = initial?.color;
    final isNew = initial == null;

    return showDialog<({String key, String label, String? color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: labelCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: '显示名'),
                ),
                const SizedBox(height: 12),
                if (isNew) ...[
                  TextField(
                    controller: keyCtrl,
                    decoration: const InputDecoration(
                      labelText: '内部标识',
                      helperText: '小写字母 / 数字 / 下划线',
                      helperStyle: TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '内部标识：${initial.key}（不可改）',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                const Text('颜色', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _palette)
                      GestureDetector(
                        onTap: () => setDialogState(() => color = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _parseColor(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? Colors.black
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: c == null
                              ? const Icon(Icons.close,
                                  size: 14, color: Colors.white)
                              : (color == c
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final key = keyCtrl.text.trim();
                if (label.isEmpty) return;
                if (isNew && key.isEmpty) return;
                Navigator.pop(ctx, (
                  key: isNew ? key : initial.key,
                  label: label,
                  color: color,
                ));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('状态管理'),
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
          : ListView(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '系统状态（带锁图标）不可删除，但可以改名和改色。',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = _list[i];
                    final count = _counts[s.key] ?? 0;
                    return ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _parseColor(s.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(s.label),
                      subtitle: Text(
                        '${s.key} · $count 个物品'
                        '${s.isSystem ? ' · 系统' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _edit(s),
                            tooltip: '编辑',
                          ),
                          if (s.isSystem)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Colors.grey,
                              ),
                            )
                          else
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _delete(s),
                              tooltip: '删除',
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: '新增状态',
        child: const Icon(Icons.add),
      ),
    );
  }
}