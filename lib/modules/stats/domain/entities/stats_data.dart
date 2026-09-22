/// 模块：stats / domain / entities
/// 职责：统计输出的纯数据结构。无业务逻辑，无 IO，无第三方依赖。
/// 约束：
///   1. 不 import fl_chart 或任何 UI 库。presentation 层自行适配。
///   2. 每个 Slice / Point 都是 final 字段，不可变。
library;

/// 总览卡片数据。
class Overview {
  final int totalItems;
  final double totalValue;
  final int loanedCount;
  final int expiringSoonCount;
  final int locationCount;

  const Overview({
    required this.totalItems,
    required this.totalValue,
    required this.loanedCount,
    required this.expiringSoonCount,
    required this.locationCount,
  });

  static const Overview empty = Overview(
    totalItems: 0,
    totalValue: 0,
    loanedCount: 0,
    expiringSoonCount: 0,
    locationCount: 0,
  );
}

/// 分类分布切片。
class CategorySlice {
  /// 分类 id。null 表示未分类。
  final int? categoryId;

  /// 展示标签。
  final String label;

  /// 该分类下的物品数。
  final int count;

  /// 该分类下物品的价格总和（null 价格按 0 算）。
  final double value;

  const CategorySlice({
    this.categoryId,
    required this.label,
    required this.count,
    required this.value,
  });
}

/// 位置分布切片。
class LocationSlice {
  /// 位置 id。null 表示未指定位置。
  final int? locationId;
  final String label;
  final int count;

  const LocationSlice({
    this.locationId,
    required this.label,
    required this.count,
  });
}

/// 状态分布切片。
class StatusSlice {
  /// 状态常量值。
  final String status;

  /// 展示标签（中文）。
  final String label;
  final int count;

  const StatusSlice({
    required this.status,
    required this.label,
    required this.count,
  });
}

/// 标签分布切片。
class TagSlice {
  final int tagId;
  final String label;

  /// 标签颜色（十六进制串，如 "#F44336"）。null 表示默认色。
  final String? color;

  /// 关联的物品数。
  final int count;

  const TagSlice({
    required this.tagId,
    required this.label,
    this.color,
    required this.count,
  });
}

/// 时间点。用于折线图 / 柱状图。
class TimePoint {
  final DateTime date;
  final double value;

  const TimePoint({required this.date, required this.value});
}

/// 到期预警项。
class ExpiryItem {
  final int itemId;
  final String name;

  /// 到期类型：warranty / expiry。
  final String kind;
  final DateTime dueDate;

  /// 距今天数。可能为负（已过期）。
  final int daysLeft;

  const ExpiryItem({
    required this.itemId,
    required this.name,
    required this.kind,
    required this.dueDate,
    required this.daysLeft,
  });
}