/// 模块：category / domain / ports
/// 职责：分类模块对外契约。
/// 约束：变更视为破坏性变更。
library;

import '../entities/category.dart';

/// 分类模块对外端口。
abstract class CategoryPort {
  /// 返回所有分类，按 sortOrder 升序、name 升序。
  Future<List<Category>> all();

  /// 按 id 查询。不存在返回 null。
  Future<Category?> findById(int id);

  /// 新增分类，返回新 id。name 为空抛 ValidationException。
  Future<int> create(Category category);

  /// 重命名。id 不存在抛 NotFoundException。
  Future<void> rename({required int id, required String name});

  /// 删除。id 不存在抛 NotFoundException。
  Future<void> delete(int id);
}