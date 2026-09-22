/// 模块：item / domain / entities
/// 职责：物品实体，对应 item 表一行。
/// 依赖：无。
/// 约束：
///   1. 不可变，修改通过 copyWith。
///   2. 只承载数据，不含业务方法或 IO。
///   3. 不 import 任何其他模块的实体，用裸 int 存外键，
///      校验与联查由 PortImpl 层负责。
library;

/// 物品实体。
///
/// 生命周期：由 Dao 从数据库读出，或由 UI 构造后传入 Dao 写入。
/// 可变性：不可变。
class Item {
  final int? id;
  final String name;

  /// 别名/俗称，用于搜索。多个别名用英文逗号分隔。
  final String? aliases;

  /// 所属分类 id。null 表示未分类。
  final int? categoryId;

  /// 当前位置 id。null 表示未指定位置。
  final int? locationId;

  /// 数量。默认 1。
  final double quantity;

  /// 单位。
  final String unit;

  /// 状态。取值见下方常量。
  final String status;

  final DateTime? purchaseDate;
  final double? price;
  final String currency;
  final DateTime? warrantyUntil;
  final DateTime? expiryDate;
  final String? notes;

  const Item({
    this.id,
    required this.name,
    this.aliases,
    this.categoryId,
    this.locationId,
    this.quantity = 1,
    this.unit = '件',
    this.status = statusInStock,
    this.purchaseDate,
    this.price,
    this.currency = 'CNY',
    this.warrantyUntil,
    this.expiryDate,
    this.notes,
  });

  // ---- 状态常量 ----
  static const String statusInStock = 'in_stock';
  static const String statusLoaned = 'loaned';
  static const String statusRepair = 'repair';
  static const String statusLost = 'lost';
  static const String statusDiscarded = 'discarded';
  static const String statusConsumed = 'consumed';

  /// 生成新实例，覆盖传入字段。
  ///
  /// 注意：无法用此方法清空 nullable 字段（如把 categoryId 置 null）。
  /// 需要清空时，请显式构造新 Item 或调用 clearCategory / clearLocation。
  Item copyWith({
    int? id,
    String? name,
    String? aliases,
    int? categoryId,
    int? locationId,
    double? quantity,
    String? unit,
    String? status,
    DateTime? purchaseDate,
    double? price,
    String? currency,
    DateTime? warrantyUntil,
    DateTime? expiryDate,
    String? notes,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      aliases: aliases ?? this.aliases,
      categoryId: categoryId ?? this.categoryId,
      locationId: locationId ?? this.locationId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      warrantyUntil: warrantyUntil ?? this.warrantyUntil,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
    );
  }

  /// 显式清除分类。
  Item clearCategory() => Item(
        id: id,
        name: name,
        aliases: aliases,
        locationId: locationId,
        quantity: quantity,
        unit: unit,
        status: status,
        purchaseDate: purchaseDate,
        price: price,
        currency: currency,
        warrantyUntil: warrantyUntil,
        expiryDate: expiryDate,
        notes: notes,
      );

  /// 显式清除位置。
  Item clearLocation() => Item(
        id: id,
        name: name,
        aliases: aliases,
        categoryId: categoryId,
        quantity: quantity,
        unit: unit,
        status: status,
        purchaseDate: purchaseDate,
        price: price,
        currency: currency,
        warrantyUntil: warrantyUntil,
        expiryDate: expiryDate,
        notes: notes,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'aliases': aliases,
        'category_id': categoryId,
        'location_id': locationId,
        'quantity': quantity,
        'unit': unit,
        'status': status,
        'purchase_date': purchaseDate?.toIso8601String(),
        'price': price,
        'currency': currency,
        'warranty_until': warrantyUntil?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'notes': notes,
      };

  factory Item.fromMap(Map<String, Object?> map) => Item(
        id: map['id'] as int?,
        name: map['name'] as String,
        aliases: map['aliases'] as String?,
        categoryId: map['category_id'] as int?,
        locationId: map['location_id'] as int?,
        quantity: ((map['quantity'] as num?) ?? 1).toDouble(),
        unit: (map['unit'] as String?) ?? '件',
        status: (map['status'] as String?) ?? statusInStock,
        purchaseDate: map['purchase_date'] == null
            ? null
            : DateTime.parse(map['purchase_date'] as String),
        price: (map['price'] as num?)?.toDouble(),
        currency: (map['currency'] as String?) ?? 'CNY',
        warrantyUntil: map['warranty_until'] == null
            ? null
            : DateTime.parse(map['warranty_until'] as String),
        expiryDate: map['expiry_date'] == null
            ? null
            : DateTime.parse(map['expiry_date'] as String),
        notes: map['notes'] as String?,
      );

  @override
  String toString() => 'Item(id: $id, name: $name, status: $status)';
}