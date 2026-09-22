/// 模块：event / domain / entities
/// 职责：事件实体，记录物品发生过的一切变更。
/// 依赖：无。
/// 约束：
///   1. 不可变。
///   2. 事件是只增不改的历史记录，不提供 copyWith。
library;

/// 事件实体。
///
/// 生命周期：由写入方构造，落库后只读。
/// 可变性：不可变。事件一旦写入不应修改。
class Event {
  final int? id;

  /// 关联的物品 id。
  ///
  /// 注意：event 模块不校验 item 是否存在，
  /// 校验由调用方（如 ItemPortImpl）负责。
  final int itemId;

  /// 事件类型。取值见下方常量。
  final String type;

  /// 事件发生时间（业务时间，非落库时间）。
  final DateTime eventDate;

  /// 来源位置 id。仅 type=move 时有效。
  final int? fromLocationId;

  /// 目标位置 id。仅 type=move 时有效。
  final int? toLocationId;

  /// 关联人员 id。仅借出/归还时有效。
  final int? personId;

  /// 数量变化。仅入库/出库/消耗时有效。
  final double? quantity;

  /// 应还日期。仅 type=loan_out 时有效。
  final DateTime? dueDate;

  /// 备注。
  final String? note;

  const Event({
    this.id,
    required this.itemId,
    required this.type,
    required this.eventDate,
    this.fromLocationId,
    this.toLocationId,
    this.personId,
    this.quantity,
    this.dueDate,
    this.note,
  });

  // ---- 事件类型常量 ----
  // 用常量而非 enum，让 DB 里直接存字符串，
  // 后续增减类型不需要动 schema。
  static const String typePurchase = 'purchase';
  static const String typeMove = 'move';
  static const String typeLoanOut = 'loan_out';
  static const String typeReturn = 'return';
  static const String typeRepair = 'repair';
  static const String typeDiscard = 'discard';
  static const String typeConsume = 'consume';
  static const String typeStockIn = 'stock_in';
  static const String typeStockOut = 'stock_out';

  // ---- 命名构造：让调用方不必记 type 常量 ----

  /// 移动位置事件。
  factory Event.move({
    required int itemId,
    int? fromLocationId,
    int? toLocationId,
    DateTime? at,
    String? note,
  }) =>
      Event(
        itemId: itemId,
        type: typeMove,
        eventDate: at ?? DateTime.now(),
        fromLocationId: fromLocationId,
        toLocationId: toLocationId,
        note: note,
      );

  /// 借出事件。
  factory Event.loanOut({
    required int itemId,
    int? personId,
    DateTime? dueDate,
    DateTime? at,
    String? note,
  }) =>
      Event(
        itemId: itemId,
        type: typeLoanOut,
        eventDate: at ?? DateTime.now(),
        personId: personId,
        dueDate: dueDate,
        note: note,
      );

  /// 归还事件。
  factory Event.returned({
    required int itemId,
    int? personId,
    DateTime? at,
    String? note,
  }) =>
      Event(
        itemId: itemId,
        type: typeReturn,
        eventDate: at ?? DateTime.now(),
        personId: personId,
        note: note,
      );

  /// 入库事件。
  factory Event.stockIn({
    required int itemId,
    double? quantity,
    DateTime? at,
    String? note,
  }) =>
      Event(
        itemId: itemId,
        type: typeStockIn,
        eventDate: at ?? DateTime.now(),
        quantity: quantity,
        note: note,
      );

  /// 消耗事件。
  factory Event.consume({
    required int itemId,
    double? quantity,
    DateTime? at,
    String? note,
  }) =>
      Event(
        itemId: itemId,
        type: typeConsume,
        eventDate: at ?? DateTime.now(),
        quantity: quantity,
        note: note,
      );

  /// 转数据库行。
  ///
  /// DateTime 统一序列化为 ISO8601 字符串，
  /// 反序列化时用 DateTime.parse 还原。
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'item_id': itemId,
        'type': type,
        'event_date': eventDate.toIso8601String(),
        'from_location_id': fromLocationId,
        'to_location_id': toLocationId,
        'person_id': personId,
        'quantity': quantity,
        'due_date': dueDate?.toIso8601String(),
        'note': note,
      };

  factory Event.fromMap(Map<String, Object?> map) => Event(
        id: map['id'] as int?,
        itemId: map['item_id'] as int,
        type: map['type'] as String,
        eventDate: DateTime.parse(map['event_date'] as String),
        fromLocationId: map['from_location_id'] as int?,
        toLocationId: map['to_location_id'] as int?,
        personId: map['person_id'] as int?,
        quantity: (map['quantity'] as num?)?.toDouble(),
        dueDate: map['due_date'] == null
            ? null
            : DateTime.parse(map['due_date'] as String),
        note: map['note'] as String?,
      );

  @override
  String toString() => 'Event(id: $id, itemId: $itemId, type: $type)';
}