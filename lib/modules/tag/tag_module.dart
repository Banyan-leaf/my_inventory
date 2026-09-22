/// 模块：tag
/// 职责：tag 模块装配入口。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/tag_dao.dart';
import 'data/port/tag_port_impl.dart';
import 'domain/ports/tag_port.dart';

class TagModule {
  static void register(AppDatabase db) {
    final dao = TagDao(db.raw);
    PortRegistry.instance.register<TagPort>(TagPortImpl(dao));
  }
}