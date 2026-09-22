/// 模块：status / domain / ports
/// 职责：状态模块对外契约。
/// 约束：
///   1. key 一旦创建不可改。
///   2. is_system 状态禁止删除。
///   3. 删除自定义状态时，调用方负责迁移物品。
library;

import '../entities/item_status.dart';

abstract class StatusPort {
  Future<List<ItemStatus>> all();
  Future<ItemStatus?> findByKey(String key);

  /// 新增自定义状态。key 必须唯一。
  Future<void> create({
    required String key,
    required String label,
    String? color,
  });

  /// 改名。系统状态也允许改名。
  Future<void> rename({required String key, required String newLabel});

  /// 改颜色。系统状态也允许改色。
  Future<void> updateColor({required String key, String? color});

  /// 删除自定义状态。
  ///
  /// 抛出 [ValidationException] 当 key 对应 is_system=true。
  /// 抛出 [NotFoundException] 当 key 不存在。
  Future<void> delete(String key);

  /// 状态是否存在于表中。
  Future<bool> exists(String key);

  /// 该状态下的物品数量。
  Future<int> countItems(String statusKey);
}