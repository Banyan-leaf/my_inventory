/// 模块：item / domain / ports
/// 职责：item 模块对外契约。
/// 依赖：同模块的 entities/item.dart。
/// 约束：
///   1. 其他模块只能通过此接口操作物品。
///   2. 变更视为破坏性变更，需同步所有调用方。
library;

import '../entities/item.dart';

/// 物品摘要，跨模块传输用的最小数据集。
class ItemBrief {
  final int id;
  final String name;
  final int? locationId;
  final int? categoryId;
  final String status;

  const ItemBrief({
    required this.id,
    required this.name,
    this.locationId,
    this.categoryId,
    required this.status,
  });
}

/// 物品统计快照。
///
/// 专供 stats 模块聚合使用，包含价格与日期字段。
/// 比 [ItemBrief] 重，但比完整 [Item] 轻，不含 notes/aliases 等文本字段。
class ItemSnapshot {
  final int id;
  final String name;
  final int? categoryId;
  final int? locationId;
  final String status;
  final double quantity;
  final double? price;
  final DateTime? purchaseDate;
  final DateTime? expiryDate;
  final DateTime? warrantyUntil;
  final DateTime? createdAt;

  const ItemSnapshot({
    required this.id,
    required this.name,
    this.categoryId,
    this.locationId,
    required this.status,
    required this.quantity,
    this.price,
    this.purchaseDate,
    this.expiryDate,
    this.warrantyUntil,
    this.createdAt,
  });
}

/// 物品查询过滤器。
class ItemQuery {
  final String? keyword;
  final int? locationId;
  final int? categoryId;
  final String? status;
  final bool includeDeleted;

  const ItemQuery({
    this.keyword,
    this.locationId,
    this.categoryId,
    this.status,
    this.includeDeleted = false,
  });
}

/// item 模块对外端口。
abstract class ItemPort {
  /// 新增物品。返回新 id。
  ///
  /// 校验：name 非空、quantity > 0、外键存在。
  /// 副作用：写入一条 event（type=stock_in）。
  Future<int> create(Item item);

  /// 更新物品。以 item.id 为准。
  Future<void> update(Item item);

  /// 软删除。写入 deleted_at，不物理删除。
  Future<void> softDelete(int id);

  /// 按 id 查询。已删除的返回 null。
  Future<Item?> findById(int id);

  /// 条件查询，返回摘要列表。
  Future<List<ItemBrief>> listBriefs({ItemQuery query = const ItemQuery()});

  /// 全量快照，供 stats 模块聚合。
  ///
  /// 不分页。个人物品数量不大，全量拉取后由调用方聚合。
  /// 已删除物品不返回。
  Future<List<ItemSnapshot>> listSnapshots();

  /// 变更物品位置。
  ///
  /// 副作用：更新 item.location_id + 写入 move 事件。
  Future<void> changeLocation({
    required int itemId,
    required int toLocationId,
  });

  /// 变更物品状态。
  ///
  /// 副作用：按状态映射写入对应事件。
  Future<void> changeStatus({
    required int itemId,
    required String status,
  });

  /// 批量变更物品状态。
  ///
  /// 只为每个物品写一条 event。
  /// [itemIds] 为空时静默返回。
  Future<void> bulkUpdateStatus({
    required List<int> itemIds,
    required String status,
  });
}