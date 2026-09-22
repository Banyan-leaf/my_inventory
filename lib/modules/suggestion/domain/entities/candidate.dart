/// 模块：suggestion / domain / entities
/// 职责：候选词实体，对应 candidate 表一行。
library;

/// 候选词。
class Candidate {
  final int? id;
  final String word;
  final String normalized;
  final String source;

  /// 所属大类。取值见 [CandidateGroups] 常量或自定义。
  final String groupName;

  /// 已录入时指向 item.id（最近一次关联）。
  final int? itemId;

  /// 权重。
  final int hitCount;

  const Candidate({
    this.id,
    required this.word,
    required this.normalized,
    this.source = sourceUser,
    this.groupName = CandidateGroups.other,
    this.itemId,
    this.hitCount = 0,
  });

  static const String sourceBuiltin = 'builtin';
  static const String sourceUser = 'user';
  static const String sourceExtracted = 'extracted';

  bool get isRecorded => itemId != null;

  Candidate copyWith({
    int? id,
    String? word,
    String? normalized,
    String? source,
    String? groupName,
    int? itemId,
    int? hitCount,
  }) {
    return Candidate(
      id: id ?? this.id,
      word: word ?? this.word,
      normalized: normalized ?? this.normalized,
      source: source ?? this.source,
      groupName: groupName ?? this.groupName,
      itemId: itemId ?? this.itemId,
      hitCount: hitCount ?? this.hitCount,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'word': word,
        'normalized': normalized,
        'source': source,
        'group_name': groupName,
        'item_id': itemId,
        'hit_count': hitCount,
      };

  factory Candidate.fromMap(Map<String, Object?> map) => Candidate(
        id: map['id'] as int?,
        word: map['word'] as String,
        normalized: map['normalized'] as String,
        source: (map['source'] as String?) ?? sourceUser,
        groupName: (map['group_name'] as String?) ?? CandidateGroups.other,
        itemId: map['item_id'] as int?,
        hitCount: (map['hit_count'] as int?) ?? 0,
      );

  @override
  String toString() =>
      'Candidate(id: $id, word: $word, group: $groupName, itemId: $itemId)';
}

/// 候选词大类常量。
///
/// key 是数据库里存的标识，value 是显示名。
/// 加新大类时，只改这里 + 建对应的 words/xxx.dart。
class CandidateGroups {
  CandidateGroups._();

  /// 兜底大类 key。永远存在，不可删除、不可重命名。
  static const String otherKey = 'other';

  static const String tools = 'tools';
  static const String digital = 'digital';
  static const String kitchen = 'kitchen';
  static const String medicine = 'medicine';
  static const String stationery = 'stationery';
  static const String daily = 'daily';
  static const String cleaning = 'cleaning';
  static const String hardware = 'hardware';
  static const String clothing = 'clothing';
  static const String sports = 'sports';
  static const String baby = 'baby';
  static const String pet = 'pet';
  static const String automotive = 'automotive';
  static const String furniture = 'furniture';
  static const String appliance = 'appliance';
  static const String gardening = 'gardening';
  static const String other = 'other';

  /// 所有内置大类（不含 other）。
  static const List<String> builtinCategories = [
    tools, digital, kitchen, medicine, stationery, daily,
    cleaning, hardware, clothing, sports, baby, pet,
    automotive, furniture, appliance, gardening,
  ];

  /// 所有大类（含 other）。
  static const List<String> all = [
    ...builtinCategories,
    other,
  ];

  /// 中文标签映射。
  static const Map<String, String> labels = {
    tools: '工具',
    digital: '数码',
    kitchen: '厨房',
    medicine: '药品',
    stationery: '文具',
    daily: '日用',
    cleaning: '清洁',
    hardware: '五金',
    clothing: '服饰',
    sports: '运动',
    baby: '母婴',
    pet: '宠物',
    automotive: '汽车',
    furniture: '家具',
    appliance: '家电',
    gardening: '园艺',
    other: '其他',
  };

  /// 中文标签，未知值直接返回 key。
  static String labelOf(String key) => labels[key] ?? key;

  /// 对应的 Dart 变量名。如 'tools' -> 'wordsTools'。
  /// 用于生成 Dart 源码。
  static String dartVarName(String group) =>
      'words${group[0].toUpperCase()}${group.substring(1)}';

  /// 对应的 Dart 文件名。如 'tools' -> 'tools.dart'。
  static String dartFileName(String group) => '$group.dart';
}