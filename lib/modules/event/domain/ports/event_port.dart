/// 模块：event / domain / ports
/// 职责：事件模块对外契约。
/// 依赖：同模块的 entities/event.dart。
/// 约束：
///   1. 变更视为破坏性变更。
///   2. 其他模块写入事件必须走 append()，
///      禁止直接操作 event 表。
library;

import '../entities/event.dart';

/// 事件模块对外端口。
///
/// 生命周期：由 EventModule 启动时注册。
/// 线程模型：所有方法返回 Future。
abstract class EventPort {
  /// 追加一条事件。
  ///
  /// [event] 的 id 必须为 null。
  /// 返回新事件 id。
  ///
  /// 副作用：写入 event 表。
  /// 抛出 ValidationException 当 itemId <= 0。
  Future<int> append(Event event);

  /// 按物品查询事件时间线，最新在前。
  ///
  /// [limit] 默认 50。无副作用。
  Future<List<Event>> listByItem(int itemId, {int limit = 50});

  /// 查询某物品最近一条事件。没有返回 null。
  Future<Event?> latestByItem(int itemId);
}