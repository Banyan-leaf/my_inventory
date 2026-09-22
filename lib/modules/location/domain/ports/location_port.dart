/// 模块：location / domain / ports
/// 职责：位置模块对外契约，其他模块唯一可见的接口。
library;

import '../entities/location.dart';

/// 位置树节点。
class LocationNode {
  final Location location;
  final List<LocationNode> children;
  final String fullPath;

  const LocationNode({
    required this.location,
    required this.children,
    required this.fullPath,
  });

  String get name => location.name;
  int get id => location.id!;
  int get sortOrder => location.sortOrder;
}

/// 位置模块对外端口。
abstract class LocationPort {
  /// 获取完整位置树。
  ///
  /// 同级节点按 sort_order 升序排列。
  Future<List<LocationNode>> tree();

  /// 按 id 查询单个位置。
  Future<Location?> findById(int id);

  /// 新增位置。
  ///
  /// 新位置自动排在同级末尾。
  Future<int> create(Location location);

  /// 重命名位置。
  Future<void> rename({required int id, required String name});

  /// 删除位置。
  Future<void> delete(int id);

  /// 变更位置的父级（移动）。
  ///
  /// 移动到新父级后自动排到同级末尾。
  Future<void> changeParent({required int id, int? newParentId});

  /// 在同级中上移一格。
  ///
  /// 已在顶部时静默返回。
  Future<void> moveUp(int id);

  /// 在同级中下移一格。
  ///
  /// 已在底部时静默返回。
  Future<void> moveDown(int id);
}