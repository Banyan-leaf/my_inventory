/// 模块：status
/// 职责：status 模块装配入口。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/status_dao.dart';
import 'data/port/status_port_impl.dart';
import 'domain/ports/status_port.dart';

class StatusModule {
  static Future<void> register(AppDatabase db) async {
    final dao = StatusDao(db.raw);
    final port = StatusPortImpl(dao, db.raw);
    PortRegistry.instance.register<StatusPort>(port);
    await port.seedSystemStatuses();
  }
}