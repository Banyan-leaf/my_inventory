/// 模块：tag / domain / ports
/// 职责：标签仓储契约。
library;

import '../entities/tag.dart';

abstract class TagRepo {
  Future<List<Tag>> findAll();
  Future<Tag?> findById(int id);
  Future<int> insert(Tag tag);
  Future<void> update(Tag tag);
  Future<void> delete(int id);

  /// 查询某物品的所有标签。
  Future<List<Tag>> findByItem(int itemId);

  /// 建立物品-标签关联。已存在则忽略。
  Future<void> linkItem({required int tagId, required int itemId});

  /// 解除物品-标签关联。
  Future<void> unlinkItem({required int tagId, required int itemId});

  /// 删除某物品的所有标签关联。
  Future<void> unlinkAllByItem(int itemId);

  /// 查询某标签关联的物品数。
  Future<int> countItemsByTag(int tagId);
}