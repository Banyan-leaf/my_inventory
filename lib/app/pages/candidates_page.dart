/// 模块：app / pages / candidates
/// 职责：词库高级管理页。
/// 功能：
///   - 按大类过滤
///   - 关键词搜索
///   - 多选批量删除 / 批量改大类
///   - 导入 txt（每行一个词）
///   - 导出 txt
///   - 导出 Dart 源码（可直接粘贴到 words/xxx.dart）
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/suggestion/domain/entities/candidate.dart';
import '../../modules/suggestion/domain/entities/candidate_group.dart';
import 'group_manage_page.dart';
import '../../modules/suggestion/domain/ports/suggestion_port.dart';

class CandidatesPage extends StatefulWidget {
  const CandidatesPage({super.key});

  @override
  State<CandidatesPage> createState() => _CandidatesPageState();
}

class _CandidatesPageState extends State<CandidatesPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Candidate> _list = const [];
  Map<int, int> _linkedCounts = const {};
  Map<String, int> _groupCounts = const {};
  List<CandidateGroup> _groups = const [];

  String _filter = 'all'; // all / recorded / unrecorded
  String _orderBy = 'weight'; // weight / name
  String? _groupFilter; // null 表示全部

  bool _loading = true;
  bool _selecting = false;
  final Set<int> _selected = {};

  Timer? _debounce;

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
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _port.listAll(
      orderBy: _orderBy,
      filter: _filter,
      group: _groupFilter,
    );
    final kw = _searchCtrl.text.trim().toLowerCase();
    final filtered = kw.isEmpty
        ? all
        : all.where((c) => c.normalized.contains(kw)).toList();

    final ids = filtered.map((c) => c.id!).toList();
    final counts = ids.isEmpty
        ? <int, int>{}
        : await _port.countLinkedBatch(ids);

    final groupCounts = await _port.countByGroup();
    final groups = await _port.listGroups();

    if (!mounted) return;
    setState(() {
      _list = filtered;
      _linkedCounts = counts;
      _groupCounts = groupCounts;
      _groups = groups;
      _selected.removeWhere((id) => !ids.contains(id));
      if (_selected.isEmpty && _selecting) _selecting = false;
      _loading = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _load);
  }

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
        ..addAll(_list.map((c) => c.id!));
    });
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  // ---------- 单条操作 ----------

  Future<void> _addNew() async {
    final result = await _promptWordWithGroup(
      title: '新增候选词',
      defaultGroup: _groupFilter ?? CandidateGroups.other,
    );
    if (result == null) return;
    try {
      await _port.addCandidate(result.word, group: result.group);
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('添加失败：${e.message}')));
    }
  }

  Future<void> _edit(Candidate c) async {
    final newWord = await _promptText('编辑词条', initial: c.word);
    if (newWord == null || newWord.trim().isEmpty) return;
    try {
      await _port.updateWord(candidateId: c.id!, newWord: newWord.trim());
      AppRefresh.instance.bump();
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('编辑失败：${e.message}')));
    }
  }

  Future<void> _delete(Candidate c) async {
    final ok = await _confirm('删除候选词', '确定删除 "${c.word}" 吗？');
    if (!ok) return;
    await _port.delete(c.id!);
    AppRefresh.instance.bump();
  }

  // ---------- 批量操作 ----------

  Future<void> _bulkDelete() async {
    if (_selected.isEmpty) return;
    final ok = await _confirm(
      '批量删除 ${_selected.length} 项',
      '确定删除选中的 ${_selected.length} 个候选词吗？\n关联的物品不会被删除。',
    );
    if (!ok) return;
    await _port.bulkDelete(_selected.toList());
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    AppRefresh.instance.bump();
  }

  Future<void> _bulkChangeGroup() async {
    if (_selected.isEmpty) return;
    final group = await _pickGroup(title: '修改大类');
    if (group == null) return;
    await _port.bulkUpdateGroup(ids: _selected.toList(), group: group);
    setState(() {
      _selected.clear();
      _selecting = false;
    });
    AppRefresh.instance.bump();
  }

  // ---------- 导入 / 导出 ----------

  Future<void> _importTxt() async {
    final path = await _promptPath('导入 txt', '完整文件路径（每行一个词）');
    if (path == null || path.trim().isEmpty) return;

    final file = File(path.trim());
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('文件不存在')));
      return;
    }

    final group = await _pickGroup(title: '导入到哪个大类');
    if (group == null) return;

    try {
      final content = await file.readAsString();
      final lines = content
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final result = await _port.importWords(words: lines, group: group);
      AppRefresh.instance.bump();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入完成：新增 ${result.added}，跳过重复 ${result.skipped}，无效 ${result.invalid}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _exportTxt() async {
    final path = await _promptPath(
      '导出 txt',
      '完整保存路径',
      initial:
          '${DateTime.now().millisecondsSinceEpoch}_candidates.txt',
    );
    if (path == null || path.trim().isEmpty) return;

    try {
      final words = await _port.exportWords(group: _groupFilter);
      await File(path.trim()).writeAsString(words.join('\n'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${words.length} 条到 ${path.trim()}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$e')));
    }
  }

  Future<void> _exportDart() async {
    if (_groupFilter == null) {
      // 必须选一个大类
      final g = await _pickGroup(title: '导出哪个大类为 Dart');
      if (g == null) return;
      if (!mounted) return;
      await _showDartPreview(g);
    } else {
      await _showDartPreview(_groupFilter!);
    }
  }

  Future<void> _showDartPreview(String group) async {
    final code = await _port.exportAsDart(group);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('导出为 Dart：${CandidateGroups.labelOf(group)}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '复制下面的代码，粘贴到对应文件里，重跑 app 后生效：',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black.withValues(alpha: 0.05),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('复制到剪贴板'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(
                    '已复制。保存到 words/${CandidateGroups.dartFileName(group)}',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------- 对话框 ----------

  Future<bool> _confirm(String title, String content) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    return r == true;
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
          decoration: const InputDecoration(labelText: '内容'),
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

  Future<String?> _promptPath(
    String title,
    String hint, {
    String? initial,
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: hint),
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

  Future<String?> _pickGroup({required String title}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final g in CandidateGroups.all)
                      ListTile(
                        leading: const Icon(Icons.category_outlined),
                        title: Text(CandidateGroups.labelOf(g)),
                        subtitle: Text(g, style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '${_groupCounts[g] ?? 0}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        onTap: () => Navigator.pop(ctx, g),
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

  Future<({String word, String group})?> _promptWordWithGroup({
    required String title,
    required String defaultGroup,
  }) async {
    final ctrl = TextEditingController();
    String group = defaultGroup;
    return showDialog<({String word, String group})>(
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
                decoration: const InputDecoration(labelText: '词条'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: group,
                decoration: const InputDecoration(labelText: '大类'),
                items: [
                  for (final g in _groups)
                    DropdownMenuItem(
                      value: g.key,
                      child: Text(g.label),
                    ),
                ],
                onChanged: (v) =>
                    setStateDialog(() => group = v ?? defaultGroup),
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
                final w = ctrl.text.trim();
                if (w.isEmpty) return;
                Navigator.pop(ctx, (word: w, group: group));
              },
              child: const Text('确定'),
            ),
          ],
        ),
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
          if (!_selecting) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: '搜索词条',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _groupFilter,
                      decoration: const InputDecoration(
                        labelText: '大类',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text('全部 (${_groupCounts.values.fold(0, (a, b) => a + b)})'),
                        ),
                        for (final g in _groups)
                          DropdownMenuItem(
                            value: g.key,
                            child: Text(
                              '${g.label} (${_groupCounts[g.key] ?? 0})',
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        setState(() => _groupFilter = v);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('全部')),
                  ButtonSegment(value: 'recorded', label: Text('已录入')),
                  ButtonSegment(value: 'unrecorded', label: Text('未录入')),
                ],
                selected: {_filter},
                onSelectionChanged: (s) {
                  setState(() => _filter = s.first);
                  _load();
                },
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Text(
                    '已选 ${_selected.length} / ${_list.length}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _selected.length == _list.length
                        ? _clearSelection
                        : _selectAll,
                    child: Text(
                      _selected.length == _list.length ? '取消全选' : '全选',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? const Center(child: Text('暂无词条'))
                    : ListView.separated(
                        itemCount: _list.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) => _tile(_list[i]),
                      ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : FloatingActionButton(
              onPressed: _addNew,
              tooltip: '新增候选词',
              child: const Icon(Icons.add),
            ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('词库管理'),
      actions: [
        IconButton(
          icon: const Icon(Icons.category_outlined),
          tooltip: '大类管理',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GroupManagePage(),
              ),
            );
            _load();
          },
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '多选',
          onPressed: _list.isEmpty ? null : _toggleSelecting,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'refresh':
                _load();
                break;
              case 'import':
                _importTxt();
                break;
              case 'export_txt':
                _exportTxt();
                break;
              case 'export_dart':
                _exportDart();
                break;
              case 'order_weight':
                setState(() => _orderBy = 'weight');
                _load();
                break;
              case 'order_name':
                setState(() => _orderBy = 'name');
                _load();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'refresh', child: Text('刷新')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'import', child: Text('导入 txt')),
            PopupMenuItem(value: 'export_txt', child: Text('导出 txt')),
            PopupMenuItem(value: 'export_dart', child: Text('导出为 Dart 源码')),
            PopupMenuDivider(),
            PopupMenuItem(value: 'order_weight', child: Text('按权重排序')),
            PopupMenuItem(value: 'order_name', child: Text('按名称排序')),
          ],
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
          icon: const Icon(Icons.drive_file_move_outline),
          tooltip: '修改大类',
          onPressed: _selected.isEmpty ? null : _bulkChangeGroup,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: '批量删除',
          onPressed: _selected.isEmpty ? null : _bulkDelete,
        ),
      ],
    );
  }

  Widget _tile(Candidate c) {
    final recorded = c.isRecorded;
    final selected = _selected.contains(c.id);
    final groupLabel = _groups
        .where((g) => g.key == c.groupName)
        .map((g) => g.label)
        .firstOrNull ??
        c.groupName;

    return ListTile(
      selected: selected,
      leading: _selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => _toggleSelect(c.id!),
            )
          : Icon(
              recorded ? Icons.check_circle : Icons.radio_button_unchecked,
              color: recorded ? Colors.green : Colors.grey,
              size: 22,
            ),
      title: Text(c.word),
      subtitle: Text(
        '$groupLabel · 权重 ${c.hitCount}'
        '${recorded ? ' · 关联 ${_linkedCounts[c.id] ?? 0} 个物品' : ''}',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: _selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _edit(c),
                  tooltip: '编辑',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _delete(c),
                  tooltip: '删除',
                ),
              ],
            ),
      onTap: _selecting ? () => _toggleSelect(c.id!) : null,
      onLongPress: _selecting
          ? null
          : () {
              setState(() {
                _selecting = true;
                _selected.add(c.id!);
              });
            },
    );
  }
}