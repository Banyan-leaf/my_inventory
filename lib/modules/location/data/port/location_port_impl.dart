/// 模块：location / data / port
/// 职责：LocationPort 的实现。
/// 约束：
///   1. tree() 按 sort_order 组装。
///   2. create / changeParent 自动排到同级末尾。
///   3. moveUp / moveDown 通过交换兄弟位置并重新编号实现。
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/location.dart';
import '../../domain/ports/location_port.dart';
import '../../domain/ports/location_repo.dart';

class LocationPortImpl implements LocationPort {
  final LocationRepo _repo;

  LocationPortImpl(this._repo);

  @override
  Future<List<LocationNode>> tree() async {
    final all = await _repo.findAll();

    // 按 parentId 分桶（已在 DAO 层按 sort_order 排好）。
    final byParent = <int?, List<Location>>{};
    for (final loc in all) {
      byParent.putIfAbsent(loc.parentId, () => []).add(loc);
    }

    // 每桶再本地排序一次，避免上层数据错乱。
    for (final list in byParent.values) {
      list.sort((a, b) {
        final cmp = a.sortOrder.compareTo(b.sortOrder);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
    }

    List<LocationNode> build(int? parentId, String parentPath) {
      final children = byParent[parentId] ?? const [];
      return children.map((loc) {
        final currentPath = parentPath.isEmpty
            ? loc.name
            : '$parentPath / ${loc.name}';
        return LocationNode(
          location: loc,
          children: build(loc.id, currentPath),
          fullPath: currentPath,
        );
      }).toList();
    }

    return build(null, '');
  }

  @override
  Future<Location?> findById(int id) => _repo.findById(id);

  @override
  Future<int> create(Location location) async {
    final trimmed = location.name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('位置名称不能为空');
    }
    // 计算新位置在同级中的 sort_order：最大值 + 1
    final siblings = await _repo.findChildren(location.parentId);
    final maxOrder = siblings.isEmpty
        ? -1
        : siblings.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);

    final toInsert = Location(
      name: trimmed,
      parentId: location.parentId,
      type: location.type,
      note: location.note,
      sortOrder: maxOrder + 1,
    );
    return _repo.insert(toInsert);
  }

  @override
  Future<void> rename({required int id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('位置名称不能为空');
    }
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('位置 $id 不存在');
    }
    await _repo.update(existing.copyWith(name: trimmed));
  }

  @override
  Future<void> delete(int id) async {
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('位置 $id 不存在');
    }
    await _repo.delete(id);
  }

  @override
  Future<void> changeParent({
    required int id,
    int? newParentId,
  }) async {
    if (newParentId == id) {
      throw const ValidationException('不能把位置移动到它自己下');
    }
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('位置 $id 不存在');
    }
    if (newParentId != null) {
      final target = await _repo.findById(newParentId);
      if (target == null) {
        throw NotFoundException('目标位置 $newParentId 不存在');
      }
      // 防循环
      final all = await _repo.findAll();
      final byParent = <int?, List<int>>{};
      for (final l in all) {
        byParent.putIfAbsent(l.parentId, () => []).add(l.id!);
      }
      final stack = <int>[id];
      while (stack.isNotEmpty) {
        final cur = stack.removeLast();
        if (cur == newParentId) {
          throw const ValidationException(
            '不能把位置移动到它自己的子位置下（会形成循环）',
          );
        }
        stack.addAll(byParent[cur] ?? const []);
      }
    }

    // 移动到新父级后，重新计算 sort_order = 新同级最大值 + 1
    final newSiblings = await _repo.findChildren(newParentId);
    final maxOrder = newSiblings.isEmpty
        ? -1
        : newSiblings.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b);

    // 更新 parent_id 和 sort_order
    await _repo.update(existing.copyWith(
      parentId: newParentId,
      sortOrder: maxOrder + 1,
    ));
  }

  @override
  Future<void> moveUp(int id) async {
    final node = await _repo.findById(id);
    if (node == null) {
      throw NotFoundException('位置 $id 不存在');
    }
    final siblings = await _repo.findChildren(node.parentId);
    siblings.sort((a, b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    final index = siblings.indexWhere((s) => s.id == id);
    if (index <= 0) return;

    // 与前一个交换
    final tmp = siblings[index - 1];
    siblings[index - 1] = siblings[index];
    siblings[index] = tmp;

    await _renumber(siblings);
  }

  @override
  Future<void> moveDown(int id) async {
    final node = await _repo.findById(id);
    if (node == null) {
      throw NotFoundException('位置 $id 不存在');
    }
    final siblings = await _repo.findChildren(node.parentId);
    siblings.sort((a, b) {
      final cmp = a.sortOrder.compareTo(b.sortOrder);
      return cmp != 0 ? cmp : a.name.compareTo(b.name);
    });

    final index = siblings.indexWhere((s) => s.id == id);
    if (index < 0 || index >= siblings.length - 1) return;

    // 与后一个交换
    final tmp = siblings[index + 1];
    siblings[index + 1] = siblings[index];
    siblings[index] = tmp;

    await _renumber(siblings);
  }

  /// 重新编号：把兄弟节点按当前顺序分配 0, 1, 2, ...
  Future<void> _renumber(List<Location> siblings) async {
    final map = <int, int>{};
    for (var i = 0; i < siblings.length; i++) {
      map[siblings[i].id!] = i;
    }
    await _repo.bulkUpdateSortOrder(map);
  }
}