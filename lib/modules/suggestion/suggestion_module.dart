/// 模块：suggestion
/// 职责：suggestion 模块装配入口。
library;

import '../../core/database/app_database.dart';
import '../../core/di/port_registry.dart';
import 'data/dao/candidate_dao.dart';
import 'data/dao/candidate_group_dao.dart';
import 'data/dao/candidate_item_dao.dart';
import 'data/port/suggestion_port_impl.dart';
import 'domain/ports/suggestion_port.dart';

class SuggestionModule {
  /// 注册本模块，并完成内置词库 / 大类的 seed。
  static Future<void> register(AppDatabase db) async {
    final candidateDao = CandidateDao(db.raw);
    final linkDao = CandidateItemDao(db.raw);
    final groupDao = CandidateGroupDao(db.raw);
    final port = SuggestionPortImpl(candidateDao, linkDao, groupDao);
    PortRegistry.instance.register<SuggestionPort>(port);
    await port.seedGroupsIfNeeded();
    await port.seedBuiltinIfNeeded();
  }
}