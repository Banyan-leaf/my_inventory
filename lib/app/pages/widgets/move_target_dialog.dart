/// 模块：app / pages / widgets
/// 职责：选择目标位置的对话框。含搜索框与"移到根目录"。
/// 约束：
///   1. 返回选中的 locationId；null 表示"移到根"。
///   2. 返回特殊常量 _cancel 表示用户取消。
///   3. 传入 [excludeIds] 排除不能选的位置（含子树）。
library;

import 'package:flutter/material.dart';

import '../../../modules/location/domain/ports/location_port.dart';

/// 用户取消的特殊返回值。
const int kMoveCancelled = -999999;

/// 展示目标位置选择对话框。
///
/// 返回：
///   - `null` 表示选择"移到根目录"
///   - `int > 0` 表示选中的位置 id
///   - `kMoveCancelled` 表示取消
Future<int?> showMoveTargetDialog(
  BuildContext context, {
  required List<LocationNode> roots,
  required Set<int> excludeIds,
  String title = '移动到…',
}) {
  return showDialog<int?>(
    context: context,
    builder: (ctx) => _MoveTargetDialog(
      roots: roots,
      excludeIds: excludeIds,
      title: title,
    ),
  ).then((v) => v ?? kMoveCancelled);
}

class _MoveTargetDialog extends StatefulWidget {
  final List<LocationNode> roots;
  final Set<int> excludeIds;
  final String title;

  const _MoveTargetDialog({
    required this.roots,
    required this.excludeIds,
    required this.title,
  });

  @override
  State<_MoveTargetDialog> createState() => _MoveTargetDialogState();
}

class _MoveTargetDialogState extends State<_MoveTargetDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 420,
        height: 480,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) => setState(() => _keyword = v.trim()),
              decoration: InputDecoration(
                hintText: '搜索位置…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _keyword = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // "移到根目录"：永远可用
            Card(
              elevation: 0,
              color: Colors.teal.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.home_outlined, color: Colors.teal),
                title: const Text('移到根目录'),
                subtitle: const Text('放在最外层', style: TextStyle(fontSize: 11)),
                onTap: () => Navigator.pop(context, null),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _keyword.isEmpty
                  ? _buildTree()
                  : _buildSearchResults(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, kMoveCancelled),
          child: const Text('取消'),
        ),
      ],
    );
  }

  // ---------- 树视图 ----------

  Widget _buildTree() {
    if (widget.roots.isEmpty) {
      return const Center(
        child: Text('暂无可选位置', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView(
      children: [
        for (final n in widget.roots) ..._buildNode(n, 0),
      ],
    );
  }

  List<Widget> _buildNode(LocationNode node, int depth) {
    final excluded = widget.excludeIds.contains(node.id);
    final tiles = <Widget>[
      ListTile(
        dense: true,
        enabled: !excluded,
        contentPadding: EdgeInsets.only(left: 12 + depth * 16, right: 8),
        leading: Icon(
          excluded ? Icons.block : Icons.place_outlined,
          size: 18,
          color: excluded ? Colors.grey[400] : null,
        ),
        title: Text(
          node.name,
          style: TextStyle(
            color: excluded ? Colors.grey[400] : null,
          ),
        ),
        subtitle: excluded
            ? const Text('不可选（在选中项的子树内）',
                style: TextStyle(fontSize: 10))
            : null,
        onTap: excluded ? null : () => Navigator.pop(context, node.id),
      ),
    ];
    for (final c in node.children) {
      tiles.addAll(_buildNode(c, depth + 1));
    }
    return tiles;
  }

  // ---------- 搜索结果 ----------

  Widget _buildSearchResults() {
    final kw = _keyword.toLowerCase();
    final matched = <({LocationNode node, int depth})>[];

    void walk(List<LocationNode> nodes, int depth) {
      for (final n in nodes) {
        if (n.name.toLowerCase().contains(kw)) {
          matched.add((node: n, depth: depth));
        }
        walk(n.children, depth + 1);
      }
    }

    walk(widget.roots, 0);

    if (matched.isEmpty) {
      return const Center(
        child: Text('没有匹配的位置', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      children: [
        for (final m in matched)
          _buildSearchTile(m.node, m.depth),
      ],
    );
  }

  Widget _buildSearchTile(LocationNode node, int depth) {
    final excluded = widget.excludeIds.contains(node.id);
    return ListTile(
      dense: true,
      enabled: !excluded,
      leading: Icon(
        excluded ? Icons.block : Icons.place_outlined,
        size: 18,
        color: excluded ? Colors.grey[400] : null,
      ),
      title: Text(
        node.name,
        style: TextStyle(color: excluded ? Colors.grey[400] : null),
      ),
      subtitle: Text(
        node.fullPath,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      onTap: excluded ? null : () => Navigator.pop(context, node.id),
    );
  }
}