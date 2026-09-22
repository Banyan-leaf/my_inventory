/// 模块：stats
/// 职责：stats 模块装配入口。
/// 约束：
///   1. 只注册 StatsPort。
///   2. 必须最后注册（其内部惰性 resolve 其他所有 Port）。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/port/stats_port_impl.dart';
import 'domain/ports/stats_port.dart';

class StatsModule {
  /// [db] 当前未使用，保留参数以与其他模块装配签名一致。
  /// stats 不直接访问数据库，全部经其他 Port。
  static void register(AppDatabase db) {
    PortRegistry.instance.register<StatsPort>(StatsPortImpl());
  }
}