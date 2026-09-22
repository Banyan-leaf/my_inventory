/// 模块：tag / data / port
/// 职责：TagPort 的实现。
/// 约束：
///   1. attach/detach 直接操作 item_tag 表。
///   2. 校验只做空值检查，实体存在性由调用方（item_edit_page）保证。
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/tag.dart';
import '../../domain/ports/tag_port.dart';
import '../../domain/ports/tag_repo.dart';

class TagPortImpl implements TagPort {
  final TagRepo _repo;
  TagPortImpl(this._repo);

  @override
  Future<List<Tag>> all() => _repo.findAll();

  @override
  Future<int> create(Tag tag) async {
    final trimmed = tag.name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('标签名称不能为空');
    }
    return _repo.insert(tag.copyWith(name: trimmed));
  }

  @override
  Future<void> rename({required int id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('标签名称不能为空');
    }
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('标签 $id 不存在');
    }
    await _repo.update(existing.copyWith(name: trimmed));
  }

  @override
  Future<void> delete(int id) async {
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('标签 $id 不存在');
    }
    await _repo.delete(id);
  }

  @override
  Future<List<Tag>> listByItem(int itemId) => _repo.findByItem(itemId);

  @override
  Future<void> attachToItem({
    required int tagId,
    required int itemId,
  }) async {
    if (tagId <= 0 || itemId <= 0) {
      throw const ValidationException('tagId 和 itemId 必须为正整数');
    }
    await _repo.linkItem(tagId: tagId, itemId: itemId);
  }

  @override
  Future<void> detachFromItem({
    required int tagId,
    required int itemId,
  }) async {
    if (tagId <= 0 || itemId <= 0) {
      throw const ValidationException('tagId 和 itemId 必须为正整数');
    }
    await _repo.unlinkItem(tagId: tagId, itemId: itemId);
  }

  @override
  Future<void> detachAllFromItem(int itemId) => _repo.unlinkAllByItem(itemId);

  @override
  Future<int> countItems(int tagId) => _repo.countItemsByTag(tagId);

  @override
  Future<void> updateColor({required int id, String? color}) async {
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('标签 $id 不存在');
    }
    // 显式构造新实例，因为 copyWith 无法把 color 置为 null。
    await _repo.update(Tag(
      id: id,
      name: existing.name,
      color: color,
    ));
  }
}