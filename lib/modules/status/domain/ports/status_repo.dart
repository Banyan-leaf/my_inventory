/// 模块：status / domain / ports
/// 职责：状态仓储契约。
library;

import '../entities/item_status.dart';

abstract class StatusRepo {
  Future<List<ItemStatus>> findAll();
  Future<ItemStatus?> findByKey(String key);
  Future<void> insert(ItemStatus status);
  Future<void> update(ItemStatus status);
  Future<void> delete(String key);
  Future<int> count();
}