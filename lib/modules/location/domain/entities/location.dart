/// 模块：location / domain / entities
/// 职责：位置实体，对应数据库 location 表的一行。
library;

class Location {
  final int? id;
  final String name;
  final int? parentId;
  final String type;
  final String? note;

  /// 同级排序位。值越小越靠前。
  final int sortOrder;

  const Location({
    this.id,
    required this.name,
    this.parentId,
    this.type = typeRoom,
    this.note,
    this.sortOrder = 0,
  });

  static const String typeRoom = 'room';
  static const String typeCabinet = 'cabinet';
  static const String typeDrawer = 'drawer';
  static const String typeShelf = 'shelf';
  static const String typeBox = 'box';
  static const String typeArea = 'area';

  Location copyWith({
    int? id,
    String? name,
    int? parentId,
    String? type,
    String? note,
    int? sortOrder,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      type: type ?? this.type,
      note: note ?? this.note,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Location clearParent() => Location(
        id: id,
        name: name,
        parentId: null,
        type: type,
        note: note,
        sortOrder: sortOrder,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'parent_id': parentId,
        'type': type,
        'note': note,
        'sort_order': sortOrder,
      };

  factory Location.fromMap(Map<String, Object?> map) => Location(
        id: map['id'] as int?,
        name: map['name'] as String,
        parentId: map['parent_id'] as int?,
        type: (map['type'] as String?) ?? typeRoom,
        note: map['note'] as String?,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  @override
  String toString() =>
      'Location(id: $id, name: $name, parentId: $parentId, sortOrder: $sortOrder)';
}