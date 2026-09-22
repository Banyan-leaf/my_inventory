/// 模块：app / pages / tag
/// 职责：标签管理页。
/// 功能：列表展示、新增、重命名、改色、删除、显示关联物品数。
/// 约束：
///   1. 标签是扁平结构，无层级。
///   2. 数据变更后调 AppRefresh.bump()。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/tag/domain/entities/tag.dart';
import '../../modules/tag/domain/ports/tag_port.dart';

class TagPage extends StatefulWidget {
  const TagPage({super.key});

  @override
  State<TagPage> createState() => _TagPageState();
}

class _TagPageState extends State<TagPage> {
  List<Tag> _list = const [];

  /// tagId -> 关联物品数。
  Map<int, int> _counts = const {};

  bool _loading = true;

  TagPort get _port => PortRegistry.instance.resolve<TagPort>();

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
    final counts = <int, int>{};
    for (final t in list) {
      counts[t.id!] = await _port.countItems(t.id!);
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
    final result = await _promptTag(title: '新增标签');
    if (result == null) return;
    try {
      await _port.create(Tag(name: result.name, color: result.color));
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败：${e.message}')));
    }
  }

  Future<void> _edit(Tag t) async {
    final result = await _promptTag(title: '编辑标签', initial: t);
    if (result == null) return;
    try {
      // 改名和改颜色都原地更新，不改变 id，不影响已挂载的物品。
      if (result.name != t.name) {
        await _port.rename(id: t.id!, name: result.name);
      }
      if (result.color != t.color) {
        await _port.updateColor(id: t.id!, color: result.color);
      }
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('编辑失败：${e.message}')));
    }
  }

  Future<void> _delete(Tag t) async {
    final count = _counts[t.id] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text(
          count > 0
              ? '确定删除"${t.name}"吗？\n\n该标签已挂在 $count 个物品上，删除后物品会失去这个标签。'
              : '确定删除"${t.name}"吗？',
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
      await _port.delete(t.id!);
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败：${e.message}')));
    }
  }

  Future<({String name, String? color})?> _promptTag({
    required String title,
    Tag? initial,
  }) async {
    final ctrl = TextEditingController(text: initial?.name ?? '');
    String? color = initial?.color;

    return showDialog<({String name, String? color})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '标签名称'),
              ),
              const SizedBox(height: 16),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final name = ctrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx, (name: name, color: color));
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
        title: const Text('标签管理'),
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
          : _list.isEmpty
              ? const Center(
                  child: Text('暂无标签，点右下角 + 新建'),
                )
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = _list[i];
                    final count = _counts[t.id] ?? 0;
                    return ListTile(
                      leading: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _parseColor(t.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(t.name),
                      subtitle: Text(
                        count > 0
                            ? '关联 $count 个物品'
                            : '暂未关联物品',
                        style: TextStyle(
                          fontSize: 11,
                          color: count > 0 ? Colors.teal : Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _edit(t),
                            tooltip: '编辑',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _delete(t),
                            tooltip: '删除',
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: '新增标签',
        child: const Icon(Icons.add),
      ),
    );
  }
}