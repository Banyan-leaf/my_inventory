/// 模块：event / domain / ports
/// 职责：事件仓储契约，仅本模块内部使用。
/// 约束：
///   1. 不对外暴露，不注册到 PortRegistry。
///   2. 只做数据存取，不含业务规则。
library;

import '../entities/event.dart';

abstract class EventRepo {
  /// 插入一条事件，返回新 id。
  ///
  /// 事件落库后不可修改，因此没有 update。
  Future<int> insert(Event event);

  /// 按物品查询事件，按 event_date 降序（最新在前）。
  ///
  /// [limit] 默认 50，[offset] 默认 0，用于分页。
  Future<List<Event>> findByItem(
    int itemId, {
    int limit = 50,
    int offset = 0,
  });

  /// 查询某物品最近一条事件。没有返回 null。
  Future<Event?> findLatestByItem(int itemId);

  /// 按类型查询事件，按 event_date 降序。
  ///
  /// 主要给 stats 模块（W5）用。
  Future<List<Event>> findByType(String type, {int limit = 100});
}