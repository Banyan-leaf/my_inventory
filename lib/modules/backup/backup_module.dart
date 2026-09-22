/// 模块：backup
/// 职责：backup 模块装配入口。
/// 约束：
///   1. 只注册 BackupPort。
///   2. 依赖 AppDatabase 实例（本工程唯一直接持有 db 的 Port）。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/port/backup_port_impl.dart';
import 'domain/ports/backup_port.dart';

class BackupModule {
  static void register(AppDatabase db) {
    PortRegistry.instance.register<BackupPort>(BackupPortImpl(db));
  }
}