/// 模块：event
/// 职责：event 模块装配入口。
/// 约束：只注册 EventPort。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/event_dao.dart';
import 'data/port/event_port_impl.dart';
import 'domain/ports/event_port.dart';

class EventModule {
  static void register(AppDatabase db) {
    final dao = EventDao(db.raw);
    PortRegistry.instance.register<EventPort>(EventPortImpl(dao));
  }
}