/// 模块：category / domain / entities
/// 职责：分类实体，对应 category 表一行。
/// 依赖：无。
/// 约束：不可变，修改通过 copyWith。
library;

/// 物品分类实体。
///
/// 支持树形结构（parentId），但常用场景下是扁平列表。
class Category {
  final int? id;
  final String name;
  final int? parentId;

  /// 图标标识。存字符串而非 IconData，避免 domain 层依赖 Flutter。
  final String? icon;

  /// 排序权重，越小越靠前。
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    this.parentId,
    this.icon,
    this.sortOrder = 0,
  });

  Category copyWith({
    int? id,
    String? name,
    int? parentId,
    String? icon,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'parent_id': parentId,
        'icon': icon,
        'sort_order': sortOrder,
      };

  factory Category.fromMap(Map<String, Object?> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        parentId: map['parent_id'] as int?,
        icon: map['icon'] as String?,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );
}