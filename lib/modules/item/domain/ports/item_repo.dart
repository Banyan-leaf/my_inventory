/// 模块：item / domain / ports
/// 职责：物品仓储契约，仅本模块内部使用。
library;

import '../entities/item.dart';
import 'item_port.dart' show ItemQuery;

abstract class ItemRepo {
  Future<Item?> findById(int id);
  Future<List<Item>> search(ItemQuery query);
  Future<int> insert(Item item);
  Future<void> update(Item item);
  Future<void> softDelete(int id, DateTime deletedAt);

  /// 批量更新状态。
  Future<void> bulkUpdateStatus(List<int> ids, String status);
}