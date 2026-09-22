/// 模块：location / domain / ports
/// 职责：位置仓储契约，仅本模块内部使用。
library;

import '../entities/location.dart';

abstract class LocationRepo {
  Future<List<Location>> findAll();
  Future<Location?> findById(int id);
  Future<List<Location>> findChildren(int? parentId);
  Future<int> insert(Location location);
  Future<void> update(Location location);
  Future<void> delete(int id);

  /// 修改父级。
  Future<void> updateParent(int id, int? newParentId);

  /// 批量更新同级排序。
  ///
  /// [idToOrder] 键为位置 id，值为目标 sort_order。
  /// 用事务保证一次性写入。
  Future<void> bulkUpdateSortOrder(Map<int, int> idToOrder);
}