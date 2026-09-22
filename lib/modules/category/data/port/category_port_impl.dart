/// 模块：category / data / port
/// 职责：CategoryPort 的实现。
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/category.dart';
import '../../domain/ports/category_port.dart';
import '../../domain/ports/category_repo.dart';

class CategoryPortImpl implements CategoryPort {
  final CategoryRepo _repo;
  CategoryPortImpl(this._repo);

  @override
  Future<List<Category>> all() => _repo.findAll();

  @override
  Future<Category?> findById(int id) => _repo.findById(id);

  @override
  Future<int> create(Category category) async {
    final trimmed = category.name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('分类名称不能为空');
    }
    return _repo.insert(category.copyWith(name: trimmed));
  }

  @override
  Future<void> rename({required int id, required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('分类名称不能为空');
    }
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('分类 $id 不存在');
    }
    await _repo.update(existing.copyWith(name: trimmed));
  }

  @override
  Future<void> delete(int id) async {
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('分类 $id 不存在');
    }
    await _repo.delete(id);
  }
}