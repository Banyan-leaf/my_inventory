/// 模块：app / pages / suggest
/// 职责：联想录入页。
/// 约束：
///   1. 未录入候选：点击直接创建。
///   2. 已录入候选：点击弹菜单（再创建 / 查看已有物品）。
///   3. 无精确匹配时显示底部"创建"按钮。
///   4. 结果列表显示候选词的大类和物品的分类/位置，便于区分同名项。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/use_cases/create_item_from_candidate_use_case.dart';
import '../../core/di/port_registry.dart';
import '../../core/refresh/app_refresh.dart';
import '../../modules/category/domain/ports/category_port.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/location/domain/ports/location_port.dart';
import '../../modules/suggestion/domain/entities/candidate.dart';
import '../../modules/suggestion/domain/ports/suggestion_port.dart';
import 'candidates_page.dart';
import 'item_edit_page.dart';

class SuggestPage extends StatefulWidget {
  const SuggestPage({super.key});

  @override
  State<SuggestPage> createState() => _SuggestPageState();
}

class _SuggestPageState extends State<SuggestPage> {
  final TextEditingController _ctrl = TextEditingController();
  SuggestionResult _result = SuggestionResult.empty;
  bool _loading = false;
  Timer? _debounce;

  /// 分类 id -> 名称。
  Map<int, String> _categoryLabelById = const {};

  /// 位置 id -> 完整路径。
  Map<int, String> _locationPathById = const {};

  SuggestionPort get _port => PortRegistry.instance.resolve<SuggestionPort>();
  CategoryPort get _categoryPort =>
      PortRegistry.instance.resolve<CategoryPort>();
  LocationPort get _locationPort =>
      PortRegistry.instance.resolve<LocationPort>();

  @override
  void initState() {
    super.initState();
    AppRefresh.instance.addListener(_onRefresh);
    _loadLookups();
  }

  @override
  void dispose() {
    AppRefresh.instance.removeListener(_onRefresh);
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onRefresh() {
    if (mounted && _ctrl.text.trim().isNotEmpty) _doSearch();
    _loadLookups();
  }

  /// 加载分类名称和位置路径映射。
  Future<void> _loadLookups() async {
    final cats = await _categoryPort.all();
    final tree = await _locationPort.tree();

    final pathById = <int, String>{};
    void walk(List<dynamic> nodes) {
      for (final n in nodes) {
        pathById[n.id as int] = n.fullPath as String;
        walk(n.children);
      }
    }
    walk(tree);

    if (!mounted) return;
    setState(() {
      _categoryLabelById = {for (final c in cats) c.id!: c.name};
      _locationPathById = pathById;
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _doSearch);
    setState(() {});
  }

  Future<void> _doSearch() async {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) {
      if (!mounted) return;
      setState(() => _result = SuggestionResult.empty);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    final r = await _port.suggest(keyword: kw);
    if (!mounted) return;
    setState(() {
      _result = r;
      _loading = false;
    });
  }

  Future<void> _onCandidateTap(Candidate c) async {
    if (!c.isRecorded) {
      await _createNew(c);
      return;
    }
    await _showActionSheet(c);
  }

  Future<void> _createNew(Candidate c) async {
    final name = await _promptName(c.word);
    if (name == null || name.trim().isEmpty) return;

    try {
      final itemId = await CreateItemFromCandidateUseCase().execute(
        candidateId: c.id!,
        name: name.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已录入物品 #$itemId：${name.trim()}')),
      );
      AppRefresh.instance.bump();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    }
  }

  Future<void> _showActionSheet(Candidate c) async {
    final items = await _port.listLinkedItems(c.id!);
    if (!mounted) return;

    final groupLabel = CandidateGroups.labelOf(c.groupName);

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.label_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.word,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '大类：$groupLabel',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '权重 ${c.hitCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('再创建一个'),
              subtitle: Text('新建一个叫"${c.word}"的物品'),
              onTap: () {
                Navigator.pop(ctx);
                _createNew(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text('查看已有物品 (${items.length})'),
              onTap: () {
                Navigator.pop(ctx);
                _showLinkedItems(c, items);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkedItems(Candidate c, List<ItemBrief> items) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      '"${c.word}" 关联的物品',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.inventory_2_outlined, size: 20),
                      title: Text(it.name),
                      subtitle: Text(
                        _itemSubtitle(it),
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.edit, size: 16),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ItemEditPage(itemId: it.id),
                          ),
                        );
                        if (changed == true) AppRefresh.instance.bump();
                      },
                      onLongPress: () async {
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('解除关联'),
                            content: Text(
                                '把物品 #${it.id} 从"${c.word}"中移除吗？\n（不会删除物品本身）'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dctx, false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dctx, true),
                                child: const Text('解除'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        await _port.unlink(
                          candidateId: c.id!,
                          itemId: it.id,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        AppRefresh.instance.bump();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptName(String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('创建物品'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '物品名称',
            helperText: '确认后会创建物品并关联到该候选词',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _createFromKeyword(String keyword) async {
    final existing = _findExactItem(keyword);
    if (existing != null) {
      await _promptAddToLibrary(existing, keyword);
      return;
    }

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemEditPage(initialName: keyword),
      ),
    );
    if (changed == true) {
      AppRefresh.instance.bump();
      await _doSearch();
    }
  }

  Future<void> _promptAddToLibrary(ItemBrief item, String keyword) async {
    final groups = await _port.listGroups();
    if (!mounted) return;

    String selectedGroup =
        groups.any((g) => g.key == CandidateGroups.otherKey)
            ? CandidateGroups.otherKey
            : (groups.isEmpty ? CandidateGroups.otherKey : groups.first.key);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 8),
              Text('物品已存在'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('已有一个叫「${item.name}」的物品（#${item.id}）。'),
              const SizedBox(height: 8),
              const Text(
                '把它加入联想词库吗？加入后输入该词能更快找到。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
                  await _port.learnFromItem(
                    itemId: item.id,
                    word: keyword,
                    group: selectedGroup,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx, true);
                } catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('加入失败：$e')),
                  );
                }
              },
              child: const Text('加入词库'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      AppRefresh.instance.bump();
      await _doSearch();
    }
  }

  Future<void> _openManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CandidatesPage()),
    );
    if (mounted && _ctrl.text.trim().isNotEmpty) _doSearch();
  }

  bool _hasExactCandidate(String keyword) {
    final norm = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (norm.isEmpty) return true;
    for (final c in _result.candidates) {
      if (c.normalized == norm) return true;
    }
    return false;
  }

  ItemBrief? _findExactItem(String keyword) {
    final norm = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (norm.isEmpty) return null;
    for (final it in _result.items) {
      final n = it.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (n == norm) return it;
    }
    return null;
  }

  /// 物品副标题：物品 #ID · 分类：X · 位置完整路径。
  String _itemSubtitle(ItemBrief it) {
    final buf = StringBuffer('物品 #${it.id}');

    if (it.categoryId != null) {
      final cat = _categoryLabelById[it.categoryId];
      if (cat != null) {
        buf.write(' · 分类：$cat');
      }
    }

    if (it.locationId != null) {
      final path = _locationPathById[it.locationId];
      if (path != null) {
        buf.write(' · $path');
      } else {
        buf.write(' · 位置 #${it.locationId}');
      }
    }

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('联想录入'),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: '清空搜索',
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _doSearch,
          ),
          IconButton(
            icon: const Icon(Icons.library_books_outlined),
            tooltip: '词库管理',
            onPressed: _openManager,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: '输入关键词，如"灯"',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          _onChanged('');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_ctrl.text.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '输入关键词开始联想\n未录入：点击直接创建\n已录入：点击弹菜单选择',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    if (_result.isEmpty && !_loading) {
      return _buildEmptyState();
    }

    final keyword = _ctrl.text.trim();
    final hasExact = _hasExactCandidate(keyword);

    return ListView(
      children: [
        if (_result.items.isNotEmpty) ...[
          _sectionHeader('已有物品 (${_result.items.length})', Colors.teal),
          for (final it in _result.items)
            ListTile(
              dense: true,
              leading:
                  const Icon(Icons.inventory_2, size: 20, color: Colors.teal),
              title: Text(it.name),
              subtitle: Text(
                _itemSubtitle(it),
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ItemEditPage(itemId: it.id),
                  ),
                );
                if (changed == true) AppRefresh.instance.bump();
              },
            ),
        ],
        if (_result.candidates.isNotEmpty) ...[
          _sectionHeader(
            '词库候选 (${_result.candidates.length})',
            Colors.orange,
          ),
          for (final c in _result.candidates) _candidateTile(c),
        ],
        if (!hasExact) _buildCreateExactButton(keyword),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmptyState() {
    final keyword = _ctrl.text.trim();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              '没有找到「$keyword」',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 6),
            Text(
              '词库和已有物品里都没有匹配项',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('创建这个物品'),
              onPressed: () => _createFromKeyword(keyword),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateExactButton(String keyword) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Column(
        children: [
          Text(
            '以上都是近似匹配，没有找到「$keyword」',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: Text('创建「$keyword」'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.teal,
                side: const BorderSide(color: Colors.teal),
              ),
              onPressed: () => _createFromKeyword(keyword),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.08),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _candidateTile(Candidate c) {
    final recorded = c.isRecorded;
    final groupLabel = CandidateGroups.labelOf(c.groupName);
    return Container(
      decoration: recorded
          ? null
          : const BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.orange, width: 3),
              ),
            ),
      child: ListTile(
        dense: true,
        leading: Icon(
          recorded ? Icons.check_circle : Icons.add_circle_outline,
          size: 20,
          color: recorded ? Colors.green : Colors.orange,
        ),
        title: Text(
          c.word,
          style: TextStyle(color: recorded ? Colors.grey[700] : null),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                groupLabel,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${_sourceLabel(c.source)} · 权重 ${c.hitCount}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
        onTap: () => _onCandidateTap(c),
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'builtin':
        return '内置';
      case 'user':
        return '用户';
      case 'extracted':
        return '提取';
      default:
        return source;
    }
  }
}