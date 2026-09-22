/// 模块：category / data / dao
/// 职责：category 表的 SQL 操作。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/category.dart';
import '../../domain/ports/category_repo.dart';

class CategoryDao implements CategoryRepo {
  static const String tableName = 'category';

  final Database _db;
  CategoryDao(this._db);

  @override
  Future<List<Category>> findAll() async {
    final rows = await _db.query(tableName, orderBy: 'sort_order ASC, name ASC');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<Category?> findById(int id) async {
    final rows = await _db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  @override
  Future<int> insert(Category category) async {
    try {
      return await _db.insert(tableName, category.toMap());
    } on DatabaseException catch (e) {
      throw AppDatabaseException('新增分类失败', cause: e);
    }
  }

  @override
  Future<void> update(Category category) async {
    if (category.id == null) {
      throw const ValidationException('更新分类时 id 不能为空');
    }
    await _db.update(
      tableName,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }
}