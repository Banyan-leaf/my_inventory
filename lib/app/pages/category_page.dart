/// 模块：app / pages / category
/// 职责：分类管理页。
/// 功能：列表展示、新增、重命名、删除。
/// 约束：
///   1. 分类支持 parent_id，但本页用扁平列表展示，
///      有父级的显示为"父 / 子"。
///   2. 数据变更后调 AppRefresh.bump()。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/category/domain/entities/category.dart';
import '../../modules/category/domain/ports/category_port.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Category> _list = const [];
  bool _loading = true;

  CategoryPort get _port => PortRegistry.instance.resolve<CategoryPort>();

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
    if (!mounted) return;
    setState(() {
      _list = list;
      _loading = false;
    });
  }

  /// 构造展示标签：有父级的显示 "父 / 子"。
  String _label(Category c) {
    if (c.parentId == null) return c.name;
    final parent = _list.firstWhere(
      (e) => e.id == c.parentId,
      orElse: () => c,
    );
    return '${parent.name} / ${c.name}';
  }

  Future<void> _add() async {
    final result = await _promptCategory(title: '新增分类');
    if (result == null) return;
    try {
      await _port.create(Category(
        name: result.name,
        parentId: result.parentId,
      ));
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('创建失败：${e.message}')));
    }
  }

  Future<void> _rename(Category c) async {
    final name = await _promptText('重命名', initial: c.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await _port.rename(id: c.id!, name: name.trim());
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('重命名失败：${e.message}')));
    }
  }

  Future<void> _delete(Category c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定删除"${c.name}"吗？\n物品不会删除，只会变成"未分类"。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _port.delete(c.id!);
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
          decoration: const InputDecoration(labelText: '分类名称'),
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

  /// 新增分类的对话框。返回名称和可选父级。
  Future<({String name, int? parentId})?> _promptCategory({
    required String title,
  }) async {
    final ctrl = TextEditingController();
    int? parentId;

    return showDialog<({String name, int? parentId})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: '分类名称'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: parentId,
                decoration: const InputDecoration(labelText: '父分类（可选）'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('（无）')),
                  for (final c in _list)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(_label(c)),
                    ),
                ],
                onChanged: (v) => setStateDialog(() => parentId = v),
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
                Navigator.pop(ctx, (name: name, parentId: parentId));
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
        title: const Text('分类管理'),
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
                  child: Text('暂无分类，点右下角 + 新建'),
                )
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final c = _list[i];
                    return ListTile(
                      leading: Icon(
                        c.parentId == null
                            ? Icons.folder_outlined
                            : Icons.subdirectory_arrow_right,
                        color: c.parentId == null ? Colors.amber : Colors.grey,
                      ),
                      title: Text(_label(c)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _rename(c),
                            tooltip: '重命名',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => _delete(c),
                            tooltip: '删除',
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        tooltip: '新增分类',
        child: const Icon(Icons.add),
      ),
    );
  }
}