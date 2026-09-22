/// 模块：stats / data / port
/// 职责：StatsPort 的实现。
/// 依赖：
///   - core/di/port_registry.dart
///   - item / location / category 模块的 domain 层
/// 约束：
///   1. 不 import 任何模块的 data/。
///   2. 所有聚合逻辑集中在此文件，业务模块不感知 stats 存在。
library;

import '../../../../core/di/port_registry.dart';
import '../../../category/domain/ports/category_port.dart';
import '../../../item/domain/entities/item.dart';
import '../../../item/domain/ports/item_port.dart';
import '../../../location/domain/ports/location_port.dart';
import '../../../tag/domain/ports/tag_port.dart';
import '../../domain/entities/stats_data.dart';
import '../../domain/ports/stats_port.dart';

/// StatsPort 默认实现。
class StatsPortImpl implements StatsPort {
  StatsPortImpl();

  ItemPort get _itemPort => PortRegistry.instance.resolve<ItemPort>();
  CategoryPort get _categoryPort => PortRegistry.instance.resolve<CategoryPort>();
  LocationPort get _locationPort => PortRegistry.instance.resolve<LocationPort>();
  TagPort get _tagPort => PortRegistry.instance.resolve<TagPort>();

  /// 状态常量 -> 中文标签。
  static const Map<String, String> _statusLabels = {
    Item.statusInStock: '在库',
    Item.statusLoaned: '借出',
    Item.statusRepair: '维修',
    Item.statusLost: '丢失',
    Item.statusDiscarded: '丢弃',
    Item.statusConsumed: '耗尽',
  };

  @override
  Future<Overview> overview() async {
    final snapshots = await _itemPort.listSnapshots();
    final locations = await _locationPort.tree();

    final totalItems = snapshots.fold<int>(0, (s, e) => s + e.quantity.round());
    final totalValue =
        snapshots.fold<double>(0, (s, e) => s + (e.price ?? 0));
    final loanedCount =
        snapshots.where((e) => e.status == Item.statusLoaned).length;

    final expiring = await expiringSoon();
    return Overview(
      totalItems: totalItems,
      totalValue: totalValue,
      loanedCount: loanedCount,
      expiringSoonCount: expiring.length,
      locationCount: locations.length,
    );
  }

  @override
  Future<List<CategorySlice>> categoryDistribution() async {
    final snapshots = await _itemPort.listSnapshots();
    final categories = await _categoryPort.all();
    final labelById = {for (final c in categories) c.id!: c.name};

    final countById = <int?, int>{};
    final valueById = <int?, double>{};
    for (final s in snapshots) {
      countById[s.categoryId] = (countById[s.categoryId] ?? 0) + 1;
      valueById[s.categoryId] = (valueById[s.categoryId] ?? 0) + (s.price ?? 0);
    }

    final slices = countById.entries.map((e) {
      final label = e.key == null ? '未分类' : (labelById[e.key] ?? '已删除分类');
      return CategorySlice(
        categoryId: e.key,
        label: label,
        count: e.value,
        value: valueById[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return slices;
  }

  @override
  Future<List<LocationSlice>> locationDistribution() async {
    final snapshots = await _itemPort.listSnapshots();
    final tree = await _locationPort.tree();

    // 拍平树，用 id -> name 映射。
    final labelById = <int, String>{};
    void walk(List<LocationNode> nodes) {
      for (final n in nodes) {
        labelById[n.id] = n.fullPath;
        walk(n.children);
      }
    }
    walk(tree);

    final countById = <int?, int>{};
    for (final s in snapshots) {
      countById[s.locationId] = (countById[s.locationId] ?? 0) + 1;
    }

    final slices = countById.entries.map((e) {
      final label = e.key == null ? '未指定' : (labelById[e.key] ?? '已删除位置');
      return LocationSlice(
        locationId: e.key,
        label: label,
        count: e.value,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return slices;
  }

  @override
  Future<List<StatusSlice>> statusDistribution() async {
    final snapshots = await _itemPort.listSnapshots();
    final countByStatus = <String, int>{};
    for (final s in snapshots) {
      countByStatus[s.status] = (countByStatus[s.status] ?? 0) + 1;
    }

    return countByStatus.entries.map((e) {
      return StatusSlice(
        status: e.key,
        label: _statusLabels[e.key] ?? e.key,
        count: e.value,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  @override
  Future<List<TimePoint>> valueTrend() async {
    final snapshots = await _itemPort.listSnapshots();

    // 只保留有 purchaseDate 且 price 非空的物品。
    final withDate = snapshots
        .where((s) => s.purchaseDate != null && s.price != null)
        .toList()
      ..sort((a, b) => a.purchaseDate!.compareTo(b.purchaseDate!));

    if (withDate.isEmpty) return const [];

    // 按天分桶累加。
    final byDay = <DateTime, double>{};
    for (final s in withDate) {
      final d = DateTime(
        s.purchaseDate!.year,
        s.purchaseDate!.month,
        s.purchaseDate!.day,
      );
      byDay[d] = (byDay[d] ?? 0) + s.price!;
    }

    final sortedDays = byDay.keys.toList()..sort();
    final points = <TimePoint>[];
    var cumulative = 0.0;
    for (final d in sortedDays) {
      cumulative += byDay[d]!;
      points.add(TimePoint(date: d, value: cumulative));
    }
    return points;
  }

  @override
  Future<List<TimePoint>> intakeActivity({int days = 30}) async {
    final snapshots = await _itemPort.listSnapshots();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));

    // 初始化每天为 0，保证折线图连续。
    final buckets = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      final d = from.add(Duration(days: i));
      buckets[DateTime(d.year, d.month, d.day)] = 0;
    }

    // 注意：ItemSnapshot 未携带 createdAt，此处用 purchaseDate 兜底。
    // 若以后需要在统计层精确到"录入时间"，
    // 给 ItemSnapshot 加 createdAt 字段即可，不影响本文件其他逻辑。
    for (final s in snapshots) {
      final ref = s.purchaseDate;
      if (ref == null) continue;
      final d = DateTime(ref.year, ref.month, ref.day);
      if (buckets.containsKey(d)) {
        buckets[d] = buckets[d]! + 1;
      }
    }

    return buckets.entries
        .map((e) => TimePoint(date: e.key, value: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<ExpiryItem>> expiringSoon({int withinDays = 30}) async {
    final snapshots = await _itemPort.listSnapshots();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final items = <ExpiryItem>[];

    for (final s in snapshots) {
      final checks = <MapEntry<String, DateTime?>>[
        MapEntry('warranty', s.warrantyUntil),
        MapEntry('expiry', s.expiryDate),
      ];
      for (final c in checks) {
        if (c.value == null) continue;
        final due = c.value!;
        final diff = due.difference(today).inDays;
        if (diff <= withinDays) {
          items.add(ExpiryItem(
            itemId: s.id,
            name: s.name,
            kind: c.key,
            dueDate: due,
            daysLeft: diff,
          ));
        }
      }
    }

    items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return items;
  }

  @override
  Future<List<TagSlice>> tagDistribution() async {
    // 走 TagPort 拉数据，不直连 item_tag 表，保持模块解耦。
    final tags = await _tagPort.all();
    if (tags.isEmpty) return const [];

    final slices = <TagSlice>[];
    for (final t in tags) {
      final count = await _tagPort.countItems(t.id!);
      if (count == 0) continue;
      slices.add(TagSlice(
        tagId: t.id!,
        label: t.name,
        color: t.color,
        count: count,
      ));
    }
    slices.sort((a, b) => b.count.compareTo(a.count));
    return slices;
  }
}