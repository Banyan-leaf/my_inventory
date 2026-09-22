/// 模块：status / domain / entities
/// 职责：物品状态实体。
/// 约束：
///   1. key 不可变，作为 item.status 的存储值。
///   2. is_system=true 的状态不允许删除。
library;

class ItemStatus {
  final String key;
  final String label;
  final String? color;
  final bool isSystem;
  final int sortOrder;

  const ItemStatus({
    required this.key,
    required this.label,
    this.color,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  ItemStatus copyWith({
    String? label,
    String? color,
    bool? isSystem,
    int? sortOrder,
  }) {
    return ItemStatus(
      key: key,
      label: label ?? this.label,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'key': key,
        'label': label,
        'color': color,
        'is_system': isSystem ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory ItemStatus.fromMap(Map<String, Object?> map) => ItemStatus(
        key: map['key'] as String,
        label: map['label'] as String,
        color: map['color'] as String?,
        isSystem: (map['is_system'] as int?) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  @override
  String toString() => 'ItemStatus(key: $key, label: $label)';
}