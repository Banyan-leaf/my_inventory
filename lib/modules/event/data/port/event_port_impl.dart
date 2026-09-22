/// 模块：event / data / port
/// 职责：EventPort 的实现，包装 EventRepo 并加校验。
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/event.dart';
import '../../domain/ports/event_port.dart';
import '../../domain/ports/event_repo.dart';

/// EventPort 默认实现。
///
/// 生命周期：由 EventModule 构造并注册。
/// 线程模型：无状态，方法可并发。
class EventPortImpl implements EventPort {
  final EventRepo _repo;
  EventPortImpl(this._repo);

  @override
  Future<int> append(Event event) async {
    if (event.itemId <= 0) {
      throw const ValidationException('事件必须关联有效的 itemId');
    }
    if (event.type.isEmpty) {
      throw const ValidationException('事件类型不能为空');
    }
    // event.id 强制为空，防止调用方误传导致覆盖。
    return _repo.insert(Event(
      itemId: event.itemId,
      type: event.type,
      eventDate: event.eventDate,
      fromLocationId: event.fromLocationId,
      toLocationId: event.toLocationId,
      personId: event.personId,
      quantity: event.quantity,
      dueDate: event.dueDate,
      note: event.note,
    ));
  }

  @override
  Future<List<Event>> listByItem(int itemId, {int limit = 50}) =>
      _repo.findByItem(itemId, limit: limit);

  @override
  Future<Event?> latestByItem(int itemId) => _repo.findLatestByItem(itemId);
}