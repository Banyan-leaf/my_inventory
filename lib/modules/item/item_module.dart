/// 模块：item
/// 职责：item 模块装配入口。
/// 约束：
///   1. 只注册 ItemPort。
///   2. 不在此处 resolve 其他模块的 Port，全部推迟到方法内。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/item_dao.dart';
import 'data/port/item_port_impl.dart';
import 'domain/ports/item_port.dart';

class ItemModule {
  static void register(AppDatabase db) {
    final dao = ItemDao(db.raw);
    PortRegistry.instance.register<ItemPort>(ItemPortImpl(dao));
  }
}