/// 模块：category / domain / ports
/// 职责：分类仓储契约，仅本模块内部使用。
library;

import '../entities/category.dart';

abstract class CategoryRepo {
  Future<List<Category>> findAll();
  Future<Category?> findById(int id);
  Future<int> insert(Category category);
  Future<void> update(Category category);
  Future<void> delete(int id);
}