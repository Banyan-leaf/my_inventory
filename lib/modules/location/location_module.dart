/// 模块：location
/// 职责：location 模块的装配入口，把本模块注册到全局端口中心。
/// 依赖：core/database、core/di、本模块 data 与 domain。
/// 约束：
///   1. 只注册 LocationPort。LocationRepo 保持模块内部可见。
///   2. 其他模块调用此模块时，只能通过 `PortRegistry.resolve<LocationPort>()`。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/location_dao.dart';
import 'data/port/location_port_impl.dart';
import 'domain/ports/location_port.dart';

/// location 模块装配器。
///
/// 生命周期：无实例，全静态方法。
class LocationModule {
  /// 把本模块注册到全局端口中心。
  ///
  /// [db] 应用数据库实例，由 AppBootstrap 传入。
  /// 重复注册会由 PortRegistry 抛错。
  static void register(AppDatabase db) {
    final dao = LocationDao(db.raw);
    PortRegistry.instance.register<LocationPort>(LocationPortImpl(dao));
  }
}