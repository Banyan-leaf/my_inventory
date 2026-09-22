/// 模块：app / pages / item_edit
/// 职责：物品新建/编辑页。支持名称、别名、数量、分类、位置、状态、
///       价格、日期、备注、标签。
/// 依赖：ItemPort、LocationPort、CategoryPort、TagPort。
/// 约束：
///   1. [itemId] 为 null 表示新建。
///   2. 保存成功时 pop(true) 通知列表刷新，并调 AppRefresh.bump()。
///   3. 标签关联的增删在保存时按差异同步。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../core/refresh/app_refresh.dart';
import '../../core/settings/learning_settings.dart';
import 'widgets/learn_dialog.dart';
import '../../modules/category/domain/entities/category.dart';
import '../../modules/category/domain/ports/category_port.dart';
import '../../modules/item/domain/entities/item.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/location/domain/ports/location_port.dart';
import '../../modules/tag/domain/entities/tag.dart';
import '../../modules/tag/domain/ports/tag_port.dart';

class ItemEditPage extends StatefulWidget {
  final int? itemId;

  /// 新建模式下的预填名称。联想页跳转时传入。
  final String? initialName;

  const ItemEditPage({
    super.key,
    this.itemId,
    this.initialName,
  });

  @override
  State<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends State<ItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _aliasesCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController(text: '件');
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  int? _categoryId;
  int? _locationId;
  String _status = Item.statusInStock;
  DateTime? _purchaseDate;
  DateTime? _warrantyUntil;
  DateTime? _expiryDate;

  List<Category> _categories = const [];
  List<({int id, String label})> _locations = const [];

  /// 所有可用标签。
  List<Tag> _allTags = const [];

  /// 当前物品已选中的标签 id 集合。
  Set<int> _selectedTagIds = {};

  bool _loading = true;
  bool _saving = false;

  bool get isNew => widget.itemId == null;

  ItemPort get _itemPort => PortRegistry.instance.resolve<ItemPort>();
  CategoryPort get _categoryPort =>
      PortRegistry.instance.resolve<CategoryPort>();
  LocationPort get _locationPort =>
      PortRegistry.instance.resolve<LocationPort>();
  TagPort get _tagPort => PortRegistry.instance.resolve<TagPort>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aliasesCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final cats = await _categoryPort.all();
    final tree = await _locationPort.tree();
    final flat = <({int id, String label})>[];
    void walk(List<dynamic> nodes, int depth) {
      for (final n in nodes) {
        flat.add((id: n.id as int, label: '${'  ' * depth}${n.name}'));
        walk(n.children, depth + 1);
      }
    }

    walk(tree, 0);

    // 加载所有标签
    final tags = await _tagPort.all();

    // 新建模式：预填名称
    if (isNew && widget.initialName != null) {
      _nameCtrl.text = widget.initialName!;
    }

    // 编辑模式：加载物品字段 + 标签
    Set<int> selectedTags = {};
    if (!isNew) {
      final item = await _itemPort.findById(widget.itemId!);
      if (item != null) {
        _nameCtrl.text = item.name;
        _aliasesCtrl.text = item.aliases ?? '';
        _qtyCtrl.text = item.quantity.toString();
        _unitCtrl.text = item.unit;
        _priceCtrl.text = item.price?.toString() ?? '';
        _notesCtrl.text = item.notes ?? '';
        _categoryId = item.categoryId;
        _locationId = item.locationId;
        _status = item.status;
        _purchaseDate = item.purchaseDate;
        _warrantyUntil = item.warrantyUntil;
        _expiryDate = item.expiryDate;
      }
      final itemTags = await _tagPort.listByItem(widget.itemId!);
      selectedTags = itemTags.map((t) => t.id!).toSet();
    }

    if (!mounted) return;
    setState(() {
      _categories = cats;
      _locations = flat;
      _allTags = tags;
      _selectedTagIds = selectedTags;
      _loading = false;
    });
  }

  Future<void> _pickDate(String which) async {
    final initial = switch (which) {
      'purchase' => _purchaseDate,
      'warranty' => _warrantyUntil,
      'expiry' => _expiryDate,
      _ => null,
    } ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked == null) return;
    setState(() {
      switch (which) {
        case 'purchase':
          _purchaseDate = picked;
          break;
        case 'warranty':
          _warrantyUntil = picked;
          break;
        case 'expiry':
          _expiryDate = picked;
          break;
      }
    });
  }

  void _clearDate(String which) {
    setState(() {
      switch (which) {
        case 'purchase':
          _purchaseDate = null;
          break;
        case 'warranty':
          _warrantyUntil = null;
          break;
        case 'expiry':
          _expiryDate = null;
          break;
      }
    });
  }

  /// 快速新建分类：弹输入框 → 创建 → 刷新列表并自动选中。
  Future<void> _quickCreateCategory() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分类'),
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
    if (name == null || name.trim().isEmpty) return;

    try {
      final newId = await _categoryPort.create(Category(name: name.trim()));
      final cats = await _categoryPort.all();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _categoryId = newId;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：${e.message}')),
      );
    }
  }

  /// 快速新建标签并自动选中。
  Future<void> _quickCreateTag() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: '标签名称'),
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
    if (name == null || name.trim().isEmpty) return;

    try {
      final newId = await _tagPort.create(Tag(name: name.trim()));
      final tags = await _tagPort.all();
      if (!mounted) return;
      setState(() {
        _allTags = tags;
        _selectedTagIds.add(newId);
      });
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：${e.message}')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final qty = double.tryParse(_qtyCtrl.text) ?? 1;
      final price = _priceCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(_priceCtrl.text);

      final item = Item(
        id: widget.itemId,
        name: _nameCtrl.text.trim(),
        aliases: _aliasesCtrl.text.trim().isEmpty
            ? null
            : _aliasesCtrl.text.trim(),
        categoryId: _categoryId,
        locationId: _locationId,
        quantity: qty,
        unit: _unitCtrl.text.trim().isEmpty ? '件' : _unitCtrl.text.trim(),
        status: _status,
        purchaseDate: _purchaseDate,
        price: price,
        warrantyUntil: _warrantyUntil,
        expiryDate: _expiryDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      late final int targetItemId;
      if (isNew) {
        targetItemId = await _itemPort.create(item);
      } else {
        await _itemPort.update(item);
        targetItemId = widget.itemId!;
      }

      // 同步标签关联
      if (isNew) {
        // 新建物品：直接挂所有选中标签
        for (final id in _selectedTagIds) {
          await _tagPort.attachToItem(tagId: id, itemId: targetItemId);
        }
      } else {
        // 编辑物品：按差异同步
        final oldTags = await _tagPort.listByItem(targetItemId);
        final oldIds = oldTags.map((t) => t.id!).toSet();

        for (final id in _selectedTagIds.difference(oldIds)) {
          await _tagPort.attachToItem(tagId: id, itemId: targetItemId);
        }
        for (final id in oldIds.difference(_selectedTagIds)) {
          await _tagPort.detachFromItem(tagId: id, itemId: targetItemId);
        }
      }

      if (!mounted) return;
      AppRefresh.instance.bump();

      // 学习机制：仅新建物品时弹
      if (isNew) {
        final enabled = await LearningSettings.isEnabled();
        if (enabled && mounted) {
          await showLearnDialog(
            context,
            itemId: targetItemId,
            itemName: item.name.trim(),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? '新建物品' : '编辑物品'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: '名称 *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '名称不能为空' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aliasesCtrl,
                    decoration: const InputDecoration(
                      labelText: '别名（逗号分隔）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '数量',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _unitCtrl,
                          decoration: const InputDecoration(
                            labelText: '单位',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _categoryId,
                          decoration: const InputDecoration(
                            labelText: '分类',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('未分类')),
                            for (final c in _categories)
                              DropdownMenuItem(
                                  value: c.id, child: Text(c.name)),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: '新建分类',
                        onPressed: _quickCreateCategory,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: _locationId,
                    decoration: const InputDecoration(
                      labelText: '位置',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('未指定')),
                      for (final l in _locations)
                        DropdownMenuItem(value: l.id, child: Text(l.label)),
                    ],
                    onChanged: (v) => setState(() => _locationId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'in_stock', child: Text('在库')),
                      DropdownMenuItem(value: 'loaned', child: Text('借出')),
                      DropdownMenuItem(value: 'repair', child: Text('维修')),
                      DropdownMenuItem(value: 'lost', child: Text('丢失')),
                      DropdownMenuItem(value: 'discarded', child: Text('丢弃')),
                      DropdownMenuItem(value: 'consumed', child: Text('耗尽')),
                    ],
                    onChanged: (v) => setState(() => _status = v ?? 'in_stock'),
                  ),
                  const SizedBox(height: 16),
                  _buildTagSelector(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '价格 (CNY)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _dateRow('购买日期', _purchaseDate, 'purchase'),
                  _dateRow('保修到期', _warrantyUntil, 'warranty'),
                  _dateRow('过期日期', _expiryDate, 'expiry'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 标签多选区块。
  Widget _buildTagSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('标签', style: TextStyle(fontSize: 12)),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新建标签', style: TextStyle(fontSize: 12)),
              onPressed: _quickCreateTag,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_allTags.isEmpty)
          Text(
            '暂无标签，点上方"新建标签"创建',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in _allTags)
                FilterChip(
                  label: Text(t.name),
                  selected: _selectedTagIds.contains(t.id),
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _selectedTagIds.add(t.id!);
                      } else {
                        _selectedTagIds.remove(t.id);
                      }
                    });
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _dateRow(String label, DateTime? value, String which) {
    final text = value == null
        ? '未设置'
        : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('$label: $text'),
          ),
          TextButton(
            onPressed: () => _pickDate(which),
            child: const Text('选择'),
          ),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => _clearDate(which),
            ),
        ],
      ),
    );
  }
}