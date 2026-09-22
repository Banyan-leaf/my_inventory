/// 模块：category
/// 职责：category 模块装配入口。
/// 约束：只注册 CategoryPort。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/category_dao.dart';
import 'data/port/category_port_impl.dart';
import 'domain/ports/category_port.dart';

class CategoryModule {
  static void register(AppDatabase db) {
    final dao = CategoryDao(db.raw);
    PortRegistry.instance.register<CategoryPort>(CategoryPortImpl(dao));
  }
}