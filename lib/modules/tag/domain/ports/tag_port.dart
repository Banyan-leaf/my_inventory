/// 模块：tag / domain / ports
/// 职责：标签模块对外契约。
/// 约束：
///   1. 物品与标签是多对多关系。
///   2. 变更视为破坏性变更，需同步所有调用方。
library;

import '../entities/tag.dart';

/// 标签模块对外端口。
abstract class TagPort {
  Future<List<Tag>> all();
  Future<int> create(Tag tag);
  Future<void> rename({required int id, required String name});
  Future<void> delete(int id);

  /// 查询某物品的所有标签。
  Future<List<Tag>> listByItem(int itemId);

  /// 给物品打标签。
  ///
  /// 幂等：已关联时不重复插入。
  /// 抛出 [NotFoundException] 当 tagId 或 itemId 无效时（由调用方保证）。
  Future<void> attachToItem({required int tagId, required int itemId});

  /// 移除物品的标签。
  ///
  /// 幂等：未关联时静默返回。
  Future<void> detachFromItem({required int tagId, required int itemId});

  /// 清除物品的所有标签关联。
  Future<void> detachAllFromItem(int itemId);

  /// 某标签关联的物品数。
  Future<int> countItems(int tagId);

  /// 修改标签颜色（原地更新，不改变 id 和关联）。
  ///
  /// [color] 为十六进制串（如 "#F44336"），传 null 表示恢复默认色。
  /// 抛出 [NotFoundException] 当标签不存在。
  Future<void> updateColor({required int id, String? color});
}