/// 模块：tag / domain / entities
/// 职责：标签实体。
library;

class Tag {
  final int? id;
  final String name;

  /// 十六进制颜色串，如 "#FF5722"。null 表示使用默认色。
  final String? color;

  const Tag({this.id, required this.name, this.color});

  Tag copyWith({int? id, String? name, String? color}) => Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
      };

  factory Tag.fromMap(Map<String, Object?> map) => Tag(
        id: map['id'] as int?,
        name: map['name'] as String,
        color: map['color'] as String?,
      );
}