/// 模块：item / data / port
/// 职责：ItemPort 的实现。负责跨模块校验与事件写入。
/// 依赖：
///   - 同模块的 ItemRepo
///   - location / category / event 模块的 domain/ports 与 entities
///   - core/di/port_registry.dart（运行时解析依赖）
/// 约束：
///   1. 禁止 import 其他模块的 data/ 或 application/ 目录。
///   2. 其他模块的 Port 通过 PortRegistry.resolve 惰性获取。
library;

import '../../../../core/di/port_registry.dart';
import '../../../../core/error/app_exception.dart';
import '../../../category/domain/ports/category_port.dart';
import '../../../event/domain/entities/event.dart';
import '../../../event/domain/ports/event_port.dart';
import '../../../location/domain/ports/location_port.dart';
import '../../../status/domain/ports/status_port.dart';
import '../../domain/entities/item.dart';
import '../../domain/ports/item_port.dart';
import '../../domain/ports/item_repo.dart';

/// ItemPort 的默认实现。
class ItemPortImpl implements ItemPort {
  final ItemRepo _repo;

  ItemPortImpl(this._repo);

  EventPort get _eventPort => PortRegistry.instance.resolve<EventPort>();
  LocationPort get _locationPort =>
      PortRegistry.instance.resolve<LocationPort>();
  CategoryPort get _categoryPort =>
      PortRegistry.instance.resolve<CategoryPort>();
  StatusPort get _statusPort =>
      PortRegistry.instance.resolve<StatusPort>();

  Future<void> _validateItem(Item item) async {
    if (item.name.trim().isEmpty) {
      throw const ValidationException('物品名称不能为空');
    }
    if (item.quantity <= 0) {
      throw const ValidationException('数量必须大于 0');
    }
    if (item.locationId != null) {
      final loc = await _locationPort.findById(item.locationId!);
      if (loc == null) {
        throw NotFoundException('位置 ${item.locationId} 不存在');
      }
    }
    if (item.categoryId != null) {
      final cat = await _categoryPort.findById(item.categoryId!);
      if (cat == null) {
        throw NotFoundException('分类 ${item.categoryId} 不存在');
      }
    }
  }

  @override
  Future<int> create(Item item) async {
    await _validateItem(item);
    final id = await _repo.insert(item.copyWith(name: item.name.trim()));
    await _eventPort.append(Event.stockIn(
      itemId: id,
      quantity: item.quantity,
      note: '创建物品',
    ));
    return id;
  }

  @override
  Future<void> update(Item item) async {
    if (item.id == null) {
      throw const ValidationException('更新物品时 id 不能为空');
    }
    final existing = await _repo.findById(item.id!);
    if (existing == null) {
      throw NotFoundException('物品 ${item.id} 不存在或已删除');
    }
    await _validateItem(item);
    await _repo.update(item.copyWith(name: item.name.trim()));
  }

  @override
  Future<void> softDelete(int id) async {
    final existing = await _repo.findById(id);
    if (existing == null) {
      throw NotFoundException('物品 $id 不存在或已删除');
    }
    await _repo.softDelete(id, DateTime.now());
    await _eventPort.append(Event(
      itemId: id,
      type: Event.typeDiscard,
      eventDate: DateTime.now(),
      note: '软删除',
    ));
  }

  @override
  Future<Item?> findById(int id) => _repo.findById(id);

  @override
  Future<List<ItemBrief>> listBriefs(
      {ItemQuery query = const ItemQuery()}) async {
    final items = await _repo.search(query);
    return items
        .map((e) => ItemBrief(
              id: e.id!,
              name: e.name,
              locationId: e.locationId,
              categoryId: e.categoryId,
              status: e.status,
            ))
        .toList();
  }

  @override
  Future<List<ItemSnapshot>> listSnapshots() async {
    // 全量拉取未删除物品，转为统计快照。
    // 个人物品数量在几百到几千级别，全量在内存聚合可接受。
    final items = await _repo.search(const ItemQuery());
    return items
        .map((e) => ItemSnapshot(
              id: e.id!,
              name: e.name,
              categoryId: e.categoryId,
              locationId: e.locationId,
              status: e.status,
              quantity: e.quantity,
              price: e.price,
              purchaseDate: e.purchaseDate,
              expiryDate: e.expiryDate,
              warrantyUntil: e.warrantyUntil,
            ))
        .toList();
  }

  @override
  Future<void> changeLocation({
    required int itemId,
    required int toLocationId,
  }) async {
    final item = await _repo.findById(itemId);
    if (item == null) {
      throw NotFoundException('物品 $itemId 不存在或已删除');
    }
    final target = await _locationPort.findById(toLocationId);
    if (target == null) {
      throw NotFoundException('位置 $toLocationId 不存在');
    }

    final fromId = item.locationId;

    await _repo.update(Item(
      id: item.id,
      name: item.name,
      aliases: item.aliases,
      categoryId: item.categoryId,
      locationId: toLocationId,
      quantity: item.quantity,
      unit: item.unit,
      status: item.status,
      purchaseDate: item.purchaseDate,
      price: item.price,
      currency: item.currency,
      warrantyUntil: item.warrantyUntil,
      expiryDate: item.expiryDate,
      notes: item.notes,
    ));

    await _eventPort.append(Event.move(
      itemId: itemId,
      fromLocationId: fromId,
      toLocationId: toLocationId,
    ));
  }

  @override
  Future<void> changeStatus({
    required int itemId,
    required String status,
  }) async {
    const validStatuses = {
      Item.statusInStock,
      Item.statusLoaned,
      Item.statusRepair,
      Item.statusLost,
      Item.statusDiscarded,
      Item.statusConsumed,
    };
    if (!validStatuses.contains(status)) {
      throw ValidationException('非法状态: $status');
    }

    final item = await _repo.findById(itemId);
    if (item == null) {
      throw NotFoundException('物品 $itemId 不存在或已删除');
    }

    await _repo.update(item.copyWith(status: status));

    final eventType = _statusToEventType(status);
    if (eventType != null) {
      await _eventPort.append(Event(
        itemId: itemId,
        type: eventType,
        eventDate: DateTime.now(),
        note: '状态变更为 $status',
      ));
    }
  }

  @override
  Future<void> bulkUpdateStatus({
    required List<int> itemIds,
    required String status,
  }) async {
    if (itemIds.isEmpty) return;
    // 校验状态合法性：状态必须存在于 item_status 表
    if (!await _statusPort.exists(status)) {
      throw ValidationException('状态 $status 不存在');
    }
    await _repo.bulkUpdateStatus(itemIds, status);
  }

  String? _statusToEventType(String status) {
    switch (status) {
      case Item.statusLoaned:
        return Event.typeLoanOut;
      case Item.statusInStock:
        return Event.typeReturn;
      case Item.statusRepair:
        return Event.typeRepair;
      case Item.statusDiscarded:
        return Event.typeDiscard;
      case Item.statusConsumed:
        return Event.typeConsume;
      case Item.statusLost:
        return null;
      default:
        return null;
    }
  }
}