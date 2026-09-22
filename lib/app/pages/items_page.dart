/// 模块：app / pages / items
/// 职责：物品列表。支持搜索、多选批量删除、刷新、单条编辑、彩色标签展示。
/// 约束：
///   1. 多选模式下 AppBar 变为"已选 N 项" + 全选/取消/删除。
///   2. 数据变更后调 AppRefresh.bump()。
///   3. 标签以彩色 chip 显示在物品名下方。
///   4. 分类按树形分组，支持折叠子分类。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/category/domain/entities/category.dart';
import '../../modules/category/domain/ports/category_port.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/location/domain/ports/location_port.dart';
import '../../modules/status/domain/entities/item_status.dart';
import '../../modules/status/domain/ports/status_port.dart';
import '../../modules/tag/domain/entities/tag.dart';
import '../../modules/tag/domain/ports/tag_port.dart';
import 'item_edit_page.dart';
import 'widgets/pick_status_dialog.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final TextEditingController _ctrl = TextEditingController();

  List<ItemBrief> _items = const [];
  Map<int?, List<ItemBrief>> _groupedItems = const {};
  Map<int, List<Tag>> _tagsByItem = const {};
  Map<int, String> _locationPathById = const {};
  Map<String, ItemStatus> _statusByKey = const {};

  /// 父分类 id -> 子分类列表。null 为根分类列表。
  Map<int?, List<Category>> _categoryChildren = const {};

  /// 折叠的分类 id 集合。null 表示"未分类"。
  final Set<int?> _collapsedCategories = {};

  bool _loading = true;
  bool _selecting = false;
  final Set<int> _selected = {};

  ItemPort get _itemPort => PortRegistry.instance.resolve<ItemPort>();
  TagPort get _tagPort => PortRegistry.instance.resolve<TagPort>();
  LocationPort get _locationPort =>
      PortRegistry.instance.resolve<LocationPort>();
  CategoryPort get _categoryPort =>
      PortRegistry.instance.resolve<CategoryPort>();
  StatusPort get _statusPort =>
      PortRegistry.instance.resolve<StatusPort>();

  /// 分类色板。
  static const List<Color> _sectionPalette = [
    Color(0xFF26A69A),
    Color(0xFF5C6BC0),
    Color(0xFFFFA726),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFF42A5F5),
    Color(0xFF8D6E63),
  ];

  Color _sectionColor(int? categoryId) {
    if (categoryId == null) return const Color(0xFF9E9E9E);
    return _sectionPalette[categoryId.abs() % _sectionPalette.length];
  }

  @override
  void initState() {
    super.initState();
    AppRefresh.instance.addListener(_onRefresh);
    _load();
  }

  @override
  void dispose() {
    AppRefresh.instance.removeListener(_onRefresh);
    _ctrl.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final kw = _ctrl.text.trim();
    final items = await _itemPort.listBriefs(
      query: ItemQuery(keyword: kw.isEmpty ? null : kw),
    );

    final categories = await _categoryPort.all();
    // 构建分类树：parent id -> 子列表
    final children = <int?, List<Category>>{};
    for (final c in categories) {
      children.putIfAbsent(c.parentId, () => []).add(c);
    }
    for (final list in children.values) {
      list.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
    }

    // 按分类分组物品
    final grouped = <int?, List<ItemBrief>>{};
    for (final it in items) {
      grouped.putIfAbsent(it.categoryId, () => []).add(it);
    }

    // 位置树
    final tree = await _locationPort.tree();
    final pathById = <int, String>{};
    void walk(List<dynamic> nodes) {
      for (final n in nodes) {
        pathById[n.id as int] = n.fullPath as String;
        walk(n.children);
      }
    }
    walk(tree);

    // 状态
    final statuses = await _statusPort.all();
    final statusMap = {for (final s in statuses) s.key: s};

    // 标签
    final tagsByItem = <int, List<Tag>>{};
    for (final it in items) {
      final tags = await _tagPort.listByItem(it.id);
      if (tags.isNotEmpty) tagsByItem[it.id] = tags;
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _categoryChildren = children;
      _groupedItems = grouped;
      _locationPathById = pathById;
      _statusByKey = statusMap;
      _tagsByItem = tagsByItem;
      _selected.removeWhere((id) => !items.any((it) => it.id == id));
      if (_selected.isEmpty && _selecting) _selecting = false;
      _loading = false;
    });
  }

  // ---------- 多选 ----------

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      if (!_selecting) _selected.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selected
        ..clear()
        ..addAll(_items.map((it) => it.id));
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _bulkChangeStatus() async {
    if (_selected.isEmpty) return;
    final statusKey = await showPickStatusDialog(
      context,
      title: '把 ${_selected.length} 件物品改为…',
    );
    if (!mounted) return;
    if (statusKey == kStatusPickCancelled) return;

    try {
      await _itemPort.bulkUpdateStatus(
        itemIds: _selected.toList(),
        status: statusKey,
      );
      if (!mounted) return;
      setState(() {
        _selected.clear();
        _selecting = false;
      });
      AppRefresh.instance.bump();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('修改失败：$e')));
    }
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('批量删除 $n 项'),
        content: Text('确定删除选中的 $n 个物品吗？'),
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
    for (final id in _selected) {
      await _itemPort.softDelete(id);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    AppRefresh.instance.bump();
  }

  Future<void> _openEdit(int id) async {
    if (_selecting) {
      _toggleSelect(id);
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ItemEditPage(itemId: id)),
    );
    if (changed == true) AppRefresh.instance.bump();
  }

  Future<void> _createNew() async {
    final id = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const ItemEditPage(itemId: null)),
    );
    if (id != null) AppRefresh.instance.bump();
  }

  Future<void> _deleteSingle(ItemBrief item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除物品'),
        content: Text('确定删除 "${item.name}" 吗？'),
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
    await _itemPort.softDelete(item.id);
    AppRefresh.instance.bump();
  }

  Future<void> _onLongPress(ItemBrief item) async {
    if (_selecting) {
      _toggleSelect(item.id);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('进入多选'),
              onTap: () => Navigator.pop(ctx, 'select'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'select':
        setState(() {
          _selecting = true;
          _selected.add(item.id);
        });
        break;
      case 'delete':
        await _deleteSingle(item);
        break;
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.grey;
    return Color(0xFF000000 | value);
  }

  // ---------- 分类树渲染 ----------

  /// 折叠/展开分类。
  void _toggleCollapse(int? categoryId) {
    setState(() {
      if (_collapsedCategories.contains(categoryId)) {
        _collapsedCategories.remove(categoryId);
      } else {
        _collapsedCategories.add(categoryId);
      }
    });
  }

  /// 递归计算分类子树物品总数。
  int _countSubtree(int? categoryId) {
    var count = (_groupedItems[categoryId] ?? const []).length;
    for (final c in _categoryChildren[categoryId] ?? const []) {
      count += _countSubtree(c.id);
    }
    return count;
  }

  /// 构建整个分类树的所有 section。
  List<Widget> _buildCategoryTree() {
    final widgets = <Widget>[];
    final rootCategories = _categoryChildren[null] ?? const [];

    for (final cat in rootCategories) {
      widgets.addAll(_buildCategorySubtree(cat, 0));
    }

    // 未分类放最后
    final unclassified = _groupedItems[null] ?? const [];
    if (unclassified.isNotEmpty) {
      widgets.add(_buildCategorySection(
        categoryId: null,
        label: '未分类',
        items: unclassified,
        depth: 0,
      ));
    }

    return widgets;
  }

  /// 递归构建一个分类及其子树。
  List<Widget> _buildCategorySubtree(Category cat, int depth) {
    final widgets = <Widget>[];
    final items = _groupedItems[cat.id] ?? const [];
    final subtreeCount = _countSubtree(cat.id);
    final hasChildren =
        (_categoryChildren[cat.id] ?? const []).isNotEmpty;

    // 分类空且无子分类时不显示
    if (subtreeCount == 0 && !hasChildren) {
      return widgets;
    }

    // 只显示有物品或有子分类有物品的
    if (subtreeCount == 0) {
      return widgets;
    }

    widgets.add(_buildCategorySection(
      categoryId: cat.id,
      label: cat.name,
      items: items,
      depth: depth,
    ));

    if (!_collapsedCategories.contains(cat.id)) {
      for (final child in _categoryChildren[cat.id] ?? const []) {
        widgets.addAll(_buildCategorySubtree(child, depth + 1));
      }
    }

    return widgets;
  }

  Widget _buildCategorySection({
    required int? categoryId,
    required String label,
    required List<ItemBrief> items,
    required int depth,
  }) {
    final collapsed = _collapsedCategories.contains(categoryId);
    final hasChildren =
        (_categoryChildren[categoryId] ?? const []).isNotEmpty;
    final subtreeCount = _countSubtree(categoryId);
    final color = _sectionColor(categoryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: hasChildren ? () => _toggleCollapse(categoryId) : null,
          child: Container(
            padding: EdgeInsets.only(
              left: 12.0 + depth * 16,
              right: 12,
              top: 8,
              bottom: 8,
            ),
            color: color.withValues(alpha: 0.08),
            child: Row(
              children: [
                // 展开/折叠图标
                if (hasChildren)
                  Icon(
                    collapsed ? Icons.chevron_right : Icons.expand_more,
                    size: 18,
                    color: color,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 4),
                // 色块
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                // 计数
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hasChildren
                        ? '$subtreeCount 件'
                        : '${items.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          for (final it in items)
            Padding(
              padding: EdgeInsets.only(left: depth * 8.0),
              child: _buildItemTile(it),
            ),
      ],
    );
  }

  // ---------- 物品项 ----------

  Widget _buildItemTile(ItemBrief it) {
    final selected = _selected.contains(it.id);
    final tags = _tagsByItem[it.id] ?? const <Tag>[];
    final status = _statusByKey[it.status];
    final statusLabel = status?.label ?? it.status;
    final statusColor = _parseColor(status?.color);
    final locationLabel = it.locationId == null
        ? null
        : (_locationPathById[it.locationId] ?? '位置 #${it.locationId}');

    return ListTile(
      isThreeLine: tags.isNotEmpty,
      leading: _selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleSelect(it.id),
            )
          : const Icon(Icons.inventory_2_outlined),
      title: Text(it.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (locationLabel != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [for (final t in tags) _tagChip(t)],
            ),
          ],
        ],
      ),
      selected: selected,
      onTap: () => _openEdit(it.id),
      onLongPress: () => _onLongPress(it),
    );
  }

  Widget _tagChip(Tag t) {
    final color = _parseColor(t.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            t.name,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selecting ? _buildSelectAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          if (!_selecting) _buildSearchBar(),
          if (_selecting) _buildSelectionHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: _createNew,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _ctrl,
        onChanged: (_) => _load(),
        decoration: InputDecoration(
          hintText: '搜索物品名称或别名',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _ctrl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _ctrl.clear();
                    _load();
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '已选 ${_selected.length} / ${_items.length}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed:
                _selected.length == _items.length ? _clearSelection : _selectAll,
            child: Text(
              _selected.length == _items.length ? '取消全选' : '全选',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return const Center(child: Text('暂无物品，点右下角 + 创建'));
    }

    return ListView(
      children: [
        ..._buildCategoryTree(),
        const SizedBox(height: 80),
      ],
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('物品'),
      actions: [
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _items.isEmpty ? null : _toggleSelecting,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          onPressed: _load,
        ),
      ],
    );
  }

  AppBar _buildSelectAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '退出多选',
        onPressed: _toggleSelecting,
      ),
      title: Text('已选 ${_selected.length}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.flag_outlined),
          tooltip: '改状态',
          onPressed: _selected.isEmpty ? null : _bulkChangeStatus,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除选中',
          onPressed: _selected.isEmpty ? null : _deleteSelected,
        ),
      ],
    );
  }
}