/// 模块：suggestion / domain / entities
/// 职责：候选词大类实体，对应 candidate_group 表一行。
/// 约束：
///   1. key 是内部标识（如 'tools'），一旦创建不可改。
///   2. label 是显示名（如 '工具'），可重命名。
///   3. isSystem 为 true 时禁止删除。
library;

class CandidateGroup {
  final String key;
  final String label;
  final bool isSystem;
  final int sortOrder;

  const CandidateGroup({
    required this.key,
    required this.label,
    this.isSystem = false,
    this.sortOrder = 0,
  });

  CandidateGroup copyWith({String? label, bool? isSystem, int? sortOrder}) {
    return CandidateGroup(
      key: key,
      label: label ?? this.label,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'key': key,
        'label': label,
        'is_system': isSystem ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory CandidateGroup.fromMap(Map<String, Object?> map) => CandidateGroup(
        key: map['key'] as String,
        label: map['label'] as String,
        isSystem: (map['is_system'] as int?) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );

  @override
  String toString() => 'CandidateGroup(key: $key, label: $label)';
}