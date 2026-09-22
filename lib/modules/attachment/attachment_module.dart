/// 模块：attachment
/// 职责：attachment 模块装配入口。
/// 约束：只注册 AttachmentPort。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/attachment_dao.dart';
import 'data/port/attachment_port_impl.dart';
import 'data/storage/attachment_storage.dart';
import 'domain/ports/attachment_port.dart';

class AttachmentModule {
  static void register(AppDatabase db) {
    final dao = AttachmentDao(db.raw);
    final storage = AttachmentStorage();
    PortRegistry.instance
        .register<AttachmentPort>(AttachmentPortImpl(dao, storage));
  }
}