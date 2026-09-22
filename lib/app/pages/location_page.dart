/// 模块：app / pages / location
/// 职责：位置树页面。
/// 功能：
///   - 位置树 CRUD + 排序（按名称/物品数）
///   - 位置多选批量删除/移动
///   - 物品数徽章 + 弹窗查看物品（弹窗内支持物品多选批量操作）
///   - 底部虚拟节点「未分类」
/// 依赖：LocationPort + ItemPort（在 app 层组装，不违反模块解耦）。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/status/domain/entities/item_status.dart';
import '../../modules/status/domain/ports/status_port.dart';
import '../../modules/tag/domain/entities/tag.dart';
import '../../modules/tag/domain/ports/tag_port.dart';
import '../../modules/location/domain/entities/location.dart';
import '../../modules/location/domain/ports/location_port.dart';
import 'item_edit_page.dart';
import 'widgets/pick_status_dialog.dart';
import 'widgets/move_target_dialog.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  List<LocationNode> _roots = const [];
  Map<int, int> _directCounts = const {};
  Map<int, int> _subtreeCounts = const {};
  Map<int, List<ItemBrief>> _subtreeItems = const {};
  Map<int, String> _fullPathById = const {};
  List<ItemBrief> _unassignedItems = const [];

  /// 状态 key -> ItemStatus。
  Map<String, ItemStatus> _statusByKey = const {};

  /// 物品 id -> 标签列表。
  Map<int, List<Tag>> _tagsByItem = const {};
  bool _loading = true;

  final Set<int> _collapsed = {};
  bool _selecting = false;
  final Set<int> _selected = {};

  /// 排序模式。开启后显示上移/下移按钮。
  bool _ordering = false;

  LocationPort get _locationPort =>
      PortRegistry.instance.resolve<LocationPort>();
  ItemPort get _itemPort => PortRegistry.instance.resolve<ItemPort>();
  StatusPort get _statusPort =>
      PortRegistry.instance.resolve<StatusPort>();
  TagPort get _tagPort => PortRegistry.instance.resolve<TagPort>();

  @override
  void initState() {
    super.initState();
    AppRefresh.instance.addListener(_onRefresh);
    _reload();
  }

  @override
  void dispose() {
    AppRefresh.instance.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _reload();
  }

  // ---------- 数据加载 ----------

  Future<void> _reload() async {
    setState(() => _loading = true);

    final results = await Future.wait([
      _locationPort.tree(),
      _itemPort.listBriefs(),
    ]);
    final roots = results[0] as List<LocationNode>;
    final items = results[1] as List<ItemBrief>;

    final direct = <int, int>{};
    final unassigned = <ItemBrief>[];
    for (final it in items) {
      if (it.locationId != null) {
        direct[it.locationId!] = (direct[it.locationId!] ?? 0) + 1;
      } else {
        unassigned.add(it);
      }
    }

    final fullPaths = <int, String>{};
    void collectPaths(List<LocationNode> nodes) {
      for (final n in nodes) {
        fullPaths[n.id] = n.fullPath;
        collectPaths(n.children);
      }
    }
    collectPaths(roots);

    final subtree = <int, int>{};
    final subtreeItems = <int, List<ItemBrief>>{};

    (int, List<ItemBrief>) compute(LocationNode n) {
      var count = direct[n.id] ?? 0;
      final bucket = <ItemBrief>[
        for (final it in items)
          if (it.locationId == n.id) it,
      ];
      for (final c in n.children) {
        final (cc, ci) = compute(c);
        count += cc;
        bucket.addAll(ci);
      }
      subtree[n.id] = count;
      subtreeItems[n.id] = bucket;
      return (count, bucket);
    }

    for (final r in roots) {
      compute(r);
    }

    // 加载状态
    final statuses = await _statusPort.all();
    final statusMap = {for (final s in statuses) s.key: s};

    // 加载每个物品的标签
    final tagsByItem = <int, List<Tag>>{};
    for (final it in items) {
      final tags = await _tagPort.listByItem(it.id);
      if (tags.isNotEmpty) tagsByItem[it.id] = tags;
    }

    if (!mounted) return;
    setState(() {
      _roots = roots;
      _directCounts = direct;
      _subtreeCounts = subtree;
      _subtreeItems = subtreeItems;
      _fullPathById = fullPaths;
      _unassignedItems = unassigned;
      _statusByKey = statusMap;
      _tagsByItem = tagsByItem;
      final aliveIds = fullPaths.keys.toSet();
      _selected.removeWhere((id) => !aliveIds.contains(id));
      _collapsed.removeWhere((id) => !aliveIds.contains(id));
      if (_selected.isEmpty && _selecting) _selecting = false;
      _loading = false;
    });
  }

  // ---------- 位置多选 ----------

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

  void _selectAllVisible() {
    final allIds = _fullPathById.keys.toSet();
    setState(() {
      _selected
        ..clear()
        ..addAll(allIds);
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final n = _selected.length;
    final hasChildren = _nodesWithChildren();
    final willOrphan = _selected.where((id) => hasChildren.contains(id)).length;

    final message = willOrphan > 0
        ? '确定删除选中的 $n 个位置吗？\n\n'
            '其中 $willOrphan 个位置有子位置，子位置不会被删除，会移到根。'
        : '确定删除选中的 $n 个位置吗？';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('批量删除 $n 项'),
        content: Text(message),
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
      try {
        await _locationPort.delete(id);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    AppRefresh.instance.bump();
  }

  Future<void> _bulkMove() async {
    if (_selected.isEmpty) return;

    final excludeIds = <int>{};
    void collectSubtree(LocationNode n) {
      excludeIds.add(n.id);
      for (final c in n.children) {
        collectSubtree(c);
      }
    }

    void walk(List<LocationNode> nodes) {
      for (final n in nodes) {
        if (_selected.contains(n.id)) {
          collectSubtree(n);
        }
        walk(n.children);
      }
    }

    walk(_roots);

    final result = await showMoveTargetDialog(
      context,
      roots: _roots,
      excludeIds: excludeIds,
      title: '移动 ${_selected.length} 个位置到…',
    );

    if (!mounted) return;
    if (result == kMoveCancelled) return;

    final targetId = result;
    var success = 0;
    var fail = 0;
    for (final id in _selected) {
      try {
        await _locationPort.changeParent(id: id, newParentId: targetId);
        success++;
      } catch (_) {
        fail++;
      }
    }

    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    AppRefresh.instance.bump();

    final targetName = targetId == null
        ? '根目录'
        : (_fullPathById[targetId] ?? '位置 #$targetId');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fail == 0
              ? '已移动 $success 个位置到「$targetName」'
              : '移动完成：$success 成功，$fail 失败',
        ),
      ),
    );
  }

  Set<int> _nodesWithChildren() {
    final result = <int>{};
    void walk(List<LocationNode> nodes) {
      for (final n in nodes) {
        if (n.children.isNotEmpty) result.add(n.id);
        walk(n.children);
      }
    }
    walk(_roots);
    return result;
  }

  // ---------- 单条 CRUD ----------

  Future<void> _add({int? parentId}) async {
    final name = await _prompt('新增位置', '请输入名称');
    if (name == null || name.trim().isEmpty) return;
    await _locationPort.create(
      Location(name: name.trim(), parentId: parentId),
    );
    AppRefresh.instance.bump();
  }

  Future<void> _rename(LocationNode node) async {
    final name = await _prompt('重命名', '请输入新名称', initial: node.name);
    if (name == null || name.trim().isEmpty) return;
    await _locationPort.rename(id: node.id, name: name.trim());
    AppRefresh.instance.bump();
  }

  Future<void> _delete(LocationNode node) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除位置'),
        content: Text('确定删除 "${node.fullPath}" 吗？\n子位置不会被删除，会移到根。'),
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
    await _locationPort.delete(node.id);
    AppRefresh.instance.bump();
  }

  Future<String?> _prompt(String title, String hint, {String? initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
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

  // ---------- 相对位置 ----------

  int _relativeDepth(int? itemLocationId, int referenceNodeId) {
    if (itemLocationId == null) return -1;
    if (itemLocationId == referenceNodeId) return 0;
    final itemPath = _fullPathById[itemLocationId];
    final refPath = _fullPathById[referenceNodeId];
    if (itemPath == null || refPath == null) return -1;
    final itemSegs = itemPath.split(' / ').length;
    final refSegs = refPath.split(' / ').length;
    return itemSegs - refSegs;
  }

  String _relativePath(int? itemLocationId, int referenceNodeId) {
    if (itemLocationId == null) return '未指定';
    if (itemLocationId == referenceNodeId) return '';
    final itemPath = _fullPathById[itemLocationId];
    final refPath = _fullPathById[referenceNodeId];
    if (itemPath == null || refPath == null) return '?';
    if (itemPath.startsWith(refPath)) {
      final rel = itemPath.substring(refPath.length);
      if (rel.startsWith(' / ')) return rel.substring(3);
      if (rel.startsWith('/')) return rel.substring(1).trim();
      return rel;
    }
    return itemPath;
  }

  // ---------- 物品弹窗（含物品多选） ----------

  Future<void> _showItems(LocationNode node) async {
    final items = _subtreeItems[node.id] ?? const [];
    if (!mounted) return;

    final byDepth = <int, List<ItemBrief>>{};
    for (final it in items) {
      final d = _relativeDepth(it.locationId, node.id);
      byDepth.putIfAbsent(d, () => []).add(it);
    }
    final depths = byDepth.keys.toList()..sort();

    var selecting = false;
    final selected = <int>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          void toggleAll() {
            setSheetState(() {
              if (selected.length == items.length) {
                selected.clear();
              } else {
                selected
                  ..clear()
                  ..addAll(items.map((e) => e.id));
              }
            });
          }

          void toggleOne(int id) {
            setSheetState(() {
              if (selected.contains(id)) {
                selected.remove(id);
              } else {
                selected.add(id);
              }
            });
          }

          void exitSelecting() {
            setSheetState(() {
              selecting = false;
              selected.clear();
            });
          }

          Future<void> doBulkDelete() async {
            if (selected.isEmpty) return;
            final n = selected.length;
            final ok = await showDialog<bool>(
              context: sheetCtx,
              builder: (dctx) => AlertDialog(
                title: Text('批量删除 $n 件物品'),
                content: Text('确定删除选中的 $n 个物品吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            final ids = selected.toList();
            for (final id in ids) {
              try {
                await _itemPort.softDelete(id);
              } catch (_) {}
            }
            if (!sheetCtx.mounted) return;
            Navigator.pop(sheetCtx);
            AppRefresh.instance.bump();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除 $n 件物品')),
              );
            }
          }

          Future<void> doBulkStatus() async {
            if (selected.isEmpty) return;
            final statusKey = await showPickStatusDialog(
              sheetCtx,
              title: '把 ${selected.length} 件物品改为…',
            );
            if (!sheetCtx.mounted) return;
            if (statusKey == kStatusPickCancelled) return;

            try {
              await _itemPort.bulkUpdateStatus(
                itemIds: selected.toList(),
                status: statusKey,
              );
              if (!sheetCtx.mounted) return;
              Navigator.pop(sheetCtx);
              AppRefresh.instance.bump();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('状态已更新')),
                );
              }
            } catch (e) {
              if (!sheetCtx.mounted) return;
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                SnackBar(content: Text('修改失败：$e')),
              );
            }
          }

          Future<void> doBulkMove() async {
            if (selected.isEmpty) return;
            final ids = selected.toList();
            Navigator.pop(sheetCtx);

            if (!mounted) return;
            final result = await showMoveTargetDialog(
              context,
              roots: _roots,
              excludeIds: const {},
              title: '移动 ${ids.length} 件物品到…',
            );
            if (!mounted) return;
            if (result == kMoveCancelled) return;

            final targetId = result;
            if (targetId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('物品必须指定一个具体位置')),
              );
              return;
            }

            var success = 0;
            var fail = 0;
            for (final id in ids) {
              try {
                await _itemPort.changeLocation(
                  itemId: id,
                  toLocationId: targetId,
                );
                success++;
              } catch (_) {
                fail++;
              }
            }
            AppRefresh.instance.bump();
            if (!mounted) return;
            final targetName = _fullPathById[targetId] ?? '位置 #$targetId';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  fail == 0
                      ? '已移动 $success 件物品到「$targetName」'
                      : '移动完成：$success 成功，$fail 失败',
                ),
              ),
            );
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              child: Column(
                children: [
                  _buildSheetHeader(
                    sheetCtx,
                    node,
                    items,
                    selecting,
                    selected,
                    setSheetState,
                    onToggleSelecting: () {
                      setSheetState(() {
                        selecting = !selecting;
                        if (!selecting) selected.clear();
                      });
                    },
                    onToggleAll: toggleAll,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              '此位置暂无物品',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView(
                            children: [
                              for (final d in depths)
                                _buildDepthSection(
                                  sheetCtx,
                                  node,
                                  d,
                                  byDepth[d]!,
                                  selecting: selecting,
                                  selected: selected,
                                  onToggle: toggleOne,
                                ),
                            ],
                          ),
                  ),
                  if (selecting)
                    _buildSheetActionBar(
                      selected.length,
                      items.length,
                      onMove: doBulkMove,
                      onDelete: doBulkDelete,
                      onStatus: doBulkStatus,
                      onCancel: exitSelecting,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSheetHeader(
    BuildContext sheetCtx,
    LocationNode node,
    List<ItemBrief> items,
    bool selecting,
    Set<int> selected,
    StateSetter setSheetState, {
    required VoidCallback onToggleSelecting,
    required VoidCallback onToggleAll,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.place_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.fullPath,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  selecting
                      ? '已选 ${selected.length} / ${items.length}'
                      : '本层 ${_directCounts[node.id] ?? 0} 件'
                          ' · 子树共 ${items.length} 件',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (items.isNotEmpty)
            if (selecting)
              TextButton(
                onPressed: onToggleAll,
                child: Text(
                  selected.length == items.length ? '取消全选' : '全选',
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: '多选',
                onPressed: onToggleSelecting,
              ),
        ],
      ),
    );
  }

  Widget _buildSheetActionBar(
    int selectedCount,
    int total, {
    required VoidCallback onMove,
    required VoidCallback onDelete,
    required VoidCallback onStatus,
    required VoidCallback onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '退出多选',
            onPressed: onCancel,
          ),
          const SizedBox(width: 4),
          Text(
            '已选 $selectedCount / $total',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('改状态'),
            onPressed: selectedCount == 0 ? null : onStatus,
          ),
          TextButton.icon(
            icon: const Icon(Icons.drive_file_move_outline, size: 18),
            label: const Text('移动'),
            onPressed: selectedCount == 0 ? null : onMove,
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: selectedCount == 0 ? null : onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildDepthSection(
    BuildContext sheetCtx,
    LocationNode refNode,
    int depth,
    List<ItemBrief> items, {
    required bool selecting,
    required Set<int> selected,
    required void Function(int) onToggle,
  }) {
    final isSelf = depth <= 0;
    final accentColor = isSelf
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final indent = depth > 0 ? depth * 16.0 : 0.0;

    final depthLabel = switch (depth) {
      -1 => '未指定位置',
      0 => '本层',
      1 => '子层',
      _ => '第 $depth 层',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (depth > 0)
          Padding(
            padding: EdgeInsets.only(left: 16 + indent, top: 12, bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  color: accentColor.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  depthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        for (final it in items)
          _buildSheetItem(
            sheetCtx,
            refNode,
            it,
            isSelf,
            indent,
            selecting: selecting,
            isSelected: selected.contains(it.id),
            onToggle: onToggle,
          ),
      ],
    );
  }

  Widget _buildSheetItem(
    BuildContext sheetCtx,
    LocationNode refNode,
    ItemBrief it,
    bool isSelf,
    double indent, {
    required bool selecting,
    required bool isSelected,
    required void Function(int) onToggle,
  }) {
    final relPath = _relativePath(it.locationId, refNode.id);
    final accentColor = isSelf
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      margin: EdgeInsets.only(left: indent),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isSelf
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        color: selecting && isSelected
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.4)
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: selecting
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(it.id),
              )
            : Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: accentColor,
              ),
        title: Text(
          it.name,
          style: TextStyle(
            fontWeight: isSelf ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 第一行：相对位置 + 状态
              Row(
                children: [
                  _relPathChip(
                    label: isSelf ? '本层' : relPath,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  _statusChip(it),
                ],
              ),
              // 第二行：标签
              if ((_tagsByItem[it.id] ?? const []).isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in _tagsByItem[it.id]!)
                      _sheetTagChip(t),
                  ],
                ),
              ],
            ],
          ),
        ),
        isThreeLine: (_tagsByItem[it.id] ?? const []).isNotEmpty,
        trailing: selecting ? null : const Icon(Icons.edit, size: 16),
        onTap: () async {
          if (selecting) {
            onToggle(it.id);
            return;
          }
          Navigator.pop(sheetCtx);
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ItemEditPage(itemId: it.id),
            ),
          );
          if (changed == true) {
            AppRefresh.instance.bump();
          }
        },
      ),
    );
  }

  /// 状态彩色 chip。
  Widget _statusChip(ItemBrief it) {
    final status = _statusByKey[it.status];
    final label = status?.label ?? it.status;
    final color = _parseColor(status?.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 弹窗内的标签 chip（比物品页的更小）。
  Widget _sheetTagChip(Tag t) {
    final color = _parseColor(t.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 3),
          Text(
            t.name,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 十六进制串转颜色。
  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.grey;
    return Color(0xFF000000 | value);
  }

  Widget _relPathChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------- 未分类弹窗 ----------

  Future<void> _showUnassignedItems() async {
    if (!mounted) return;
    final items = _unassignedItems;

    var selecting = false;
    final selected = <int>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          void toggleAll() {
            setSheetState(() {
              if (selected.length == items.length) {
                selected.clear();
              } else {
                selected
                  ..clear()
                  ..addAll(items.map((e) => e.id));
              }
            });
          }

          void toggleOne(int id) {
            setSheetState(() {
              if (selected.contains(id)) {
                selected.remove(id);
              } else {
                selected.add(id);
              }
            });
          }

          void exitSelecting() {
            setSheetState(() {
              selecting = false;
              selected.clear();
            });
          }

          Future<void> doBulkDelete() async {
            if (selected.isEmpty) return;
            final n = selected.length;
            final ok = await showDialog<bool>(
              context: sheetCtx,
              builder: (dctx) => AlertDialog(
                title: Text('批量删除 $n 件物品'),
                content: Text('确定删除选中的 $n 个物品吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            final ids = selected.toList();
            for (final id in ids) {
              try {
                await _itemPort.softDelete(id);
              } catch (_) {}
            }
            if (!sheetCtx.mounted) return;
            Navigator.pop(sheetCtx);
            AppRefresh.instance.bump();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除 $n 件物品')),
              );
            }
          }

          Future<void> doBulkMove() async {
            if (selected.isEmpty) return;
            final ids = selected.toList();
            Navigator.pop(sheetCtx);

            if (!mounted) return;
            final result = await showMoveTargetDialog(
              context,
              roots: _roots,
              excludeIds: const {},
              title: '移动 ${ids.length} 件物品到…',
            );
            if (!mounted) return;
            if (result == kMoveCancelled) return;

            final targetId = result;
            if (targetId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('物品必须指定一个具体位置')),
              );
              return;
            }

            var success = 0;
            var fail = 0;
            for (final id in ids) {
              try {
                await _itemPort.changeLocation(
                  itemId: id,
                  toLocationId: targetId,
                );
                success++;
              } catch (_) {
                fail++;
              }
            }
            AppRefresh.instance.bump();
            if (!mounted) return;
            final targetName =
                _fullPathById[targetId] ?? '位置 #$targetId';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  fail == 0
                      ? '已移动 $success 件物品到「$targetName」'
                      : '移动完成：$success 成功，$fail 失败',
                ),
              ),
            );
          }

          Future<void> doBulkStatus() async {
            if (selected.isEmpty) return;
            final statusKey = await showPickStatusDialog(
              sheetCtx,
              title: '把 ${selected.length} 件物品改为…',
            );
            if (!sheetCtx.mounted) return;
            if (statusKey == kStatusPickCancelled) return;

            try {
              await _itemPort.bulkUpdateStatus(
                itemIds: selected.toList(),
                status: statusKey,
              );
              if (!sheetCtx.mounted) return;
              Navigator.pop(sheetCtx);
              AppRefresh.instance.bump();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('状态已更新')),
                );
              }
            } catch (e) {
              if (!sheetCtx.mounted) return;
              ScaffoldMessenger.of(sheetCtx).showSnackBar(
                SnackBar(content: Text('修改失败：$e')),
              );
            }
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.75,
              child: Column(
                children: [
                  // 头部
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '未分类物品',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                selecting
                                    ? '已选 ${selected.length} / ${items.length}'
                                    : '共 ${items.length} 件 · 尚未指定位置',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (items.isNotEmpty)
                          if (selecting)
                            TextButton(
                              onPressed: toggleAll,
                              child: Text(
                                selected.length == items.length
                                    ? '取消全选'
                                    : '全选',
                              ),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.checklist),
                              tooltip: '多选',
                              onPressed: () {
                                setSheetState(() {
                                  selecting = true;
                                  selected.clear();
                                });
                              },
                            ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              '暂无未分类物品',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final it = items[i];
                              final isSelected = selected.contains(it.id);
                              return Container(
                                color: selecting && isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                        .withValues(alpha: 0.4)
                                    : null,
                                child: ListTile(
                                  dense: true,
                                  leading: selecting
                                      ? Checkbox(
                                          value: isSelected,
                                          onChanged: (_) =>
                                              toggleOne(it.id),
                                        )
                                      : Icon(
                                          Icons.inventory_2_outlined,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  title: Text(it.name),
                                  subtitle: const Text(
                                    '未指定位置',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  trailing: selecting
                                      ? null
                                      : const Icon(Icons.edit, size: 16),
                                  onTap: () async {
                                    if (selecting) {
                                      toggleOne(it.id);
                                      return;
                                    }
                                    Navigator.pop(sheetCtx);
                                    final changed =
                                        await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ItemEditPage(itemId: it.id),
                                      ),
                                    );
                                    if (changed == true) {
                                      AppRefresh.instance.bump();
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (selecting)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: '退出多选',
                            onPressed: exitSelecting,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '已选 ${selected.length} / ${items.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('改状态'),
                            onPressed: selected.isEmpty
                                ? null
                                : doBulkStatus,
                          ),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.drive_file_move_outline,
                              size: 18,
                            ),
                            label: const Text('移动'),
                            onPressed:
                                selected.isEmpty ? null : doBulkMove,
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('删除'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed:
                                selected.isEmpty ? null : doBulkDelete,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  // ---------- 主界面 ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selecting
          ? _buildSelectAppBar()
          : (_ordering ? _buildOrderAppBar() : _buildNormalAppBar()),
      body: Column(
        children: [
          if (_selecting) _buildSelectionHeader(),
          if (_ordering) _buildOrderHint(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _roots.isEmpty && _unassignedItems.isEmpty
                    ? const Center(
                        child: Text('暂无位置，点右下角 + 添加"家"'),
                      )
                    : ListView(
                        children: [
                          for (final n in _roots) _buildNode(n, 0),
                          if (!_selecting) _buildUnassignedNode(),
                          const SizedBox(height: 80),
                        ],
                      ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: () => _add(),
              tooltip: '新增位置',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildUnassignedNode() {
    final count = _unassignedItems.length;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        onTap: count > 0 ? _showUnassignedItems : null,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            top: 12,
            bottom: 12,
            right: 8,
          ),
          child: Row(
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 20,
                color: count > 0
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Colors.grey[400],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '未分类',
                  style: TextStyle(
                    fontSize: 16,
                    color: count > 0 ? null : Colors.grey[500],
                    fontStyle: count > 0 ? null : FontStyle.italic,
                  ),
                ),
              ),
              if (count > 0)
                InkWell(
                  onTap: _showUnassignedItems,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count 件',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '0',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '点 ↑↓ 调整位置在同级中的顺序',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader() {
    final total = _fullPathById.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '已选 ${_selected.length} / $total',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          TextButton(
            onPressed:
                _selected.length == total ? _clearSelection : _selectAllVisible,
            child: Text(
              _selected.length == total ? '取消全选' : '全选',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(LocationNode node, int depth) {
    final direct = _directCounts[node.id] ?? 0;
    final total = _subtreeCounts[node.id] ?? 0;
    final hasChildren = node.children.isNotEmpty;
    final collapsed = _collapsed.contains(node.id);
    final selected = _selected.contains(node.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _selecting
              ? () => _toggleSelect(node.id)
              : (_ordering ? null : () => _add(parentId: node.id)),
          onLongPress: (_selecting || _ordering)
              ? null
              : () => _showActions(node),
          child: Container(
            color: selected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.4)
                : null,
            padding: EdgeInsets.only(
              left: 12.0 + depth * 20,
              top: 6,
              bottom: 6,
              right: 8,
            ),
            child: Row(
              children: [
                if (_selecting)
                  Checkbox(
                    value: selected,
                    onChanged: (_) => _toggleSelect(node.id),
                  )
                else if (hasChildren)
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (collapsed) {
                          _collapsed.remove(node.id);
                        } else {
                          _collapsed.add(node.id);
                        }
                      });
                    },
                    child: Icon(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 4),
                const Icon(Icons.place_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (_ordering) ...[
                  _orderButton(
                    icon: Icons.keyboard_arrow_up,
                    onTap: () => _moveNode(node.id, true),
                  ),
                  _orderButton(
                    icon: Icons.keyboard_arrow_down,
                    onTap: () => _moveNode(node.id, false),
                  ),
                  const SizedBox(width: 4),
                ] else if (total > 0)
                  _countBadge(node, direct, total)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '0',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          for (final child in node.children) _buildNode(child, depth + 1),
      ],
    );
  }

  Widget _orderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _countBadge(LocationNode node, int direct, int total) {
    final hasChildren = node.children.isNotEmpty;
    final text = hasChildren && direct != total
        ? '$total 件  · 本层 $direct'
        : '$total 件';

    return InkWell(
      onTap: _selecting ? null : () => _showItems(node),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _toggleOrdering() {
    setState(() {
      _ordering = !_ordering;
      if (_ordering) {
        // 进入排序模式时退出多选
        _selecting = false;
        _selected.clear();
      }
    });
  }

  Future<void> _moveNode(int id, bool up) async {
    try {
      if (up) {
        await _locationPort.moveUp(id);
      } else {
        await _locationPort.moveDown(id);
      }
      AppRefresh.instance.bump();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移动失败：$e')),
      );
    }
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('位置树'),
      actions: [
        IconButton(
          icon: const Icon(Icons.swap_vert),
          tooltip: '排序',
          onPressed: _roots.isEmpty ? null : _toggleOrdering,
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _roots.isEmpty ? null : _toggleSelecting,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
          onPressed: _reload,
        ),
      ],
    );
  }

  AppBar _buildOrderAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: '退出排序',
        onPressed: _toggleOrdering,
      ),
      title: const Text('调整顺序'),
      actions: [
        TextButton(
          onPressed: _toggleOrdering,
          child: const Text('完成'),
        ),
        const SizedBox(width: 8),
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
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: '移动到…',
          onPressed: _selected.isEmpty ? null : _bulkMove,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '删除选中',
          onPressed: _selected.isEmpty ? null : _bulkDelete,
        ),
      ],
    );
  }

  void _showActions(LocationNode node) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新增子位置'),
              onTap: () {
                Navigator.pop(ctx);
                _add(parentId: node.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('查看物品 (${_subtreeCounts[node.id] ?? 0})'),
              onTap: () {
                Navigator.pop(ctx);
                _showItems(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(node);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('删除'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(node);
              },
            ),
          ],
        ),
      ),
    );
  }
}
