/// 模块：app / use_cases
/// 职责：把使用某状态的物品迁移到另一个状态，然后删除原状态。
/// 依赖：ItemPort、StatusPort。
/// 约束：
///   1. 跨模块编排只在此层。
///   2. 事务性：先迁移物品，再删状态。迁移失败不删。
library;

import '../../core/di/port_registry.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/status/domain/ports/status_port.dart';

class MigrateStatusUseCase {
  /// 执行迁移。
  ///
  /// [from] 源状态 key。[to] 目标状态 key。
  /// [itemIds] 迁移哪些物品（通常是 from 状态下所有物品）。
  ///
  /// 抛出异常时不做任何补偿（本地单用户可接受）。
  Future<void> execute({
    required String from,
    required String to,
    required List<int> itemIds,
  }) async {
    if (from == to) return;

    final itemPort = PortRegistry.instance.resolve<ItemPort>();
    final statusPort = PortRegistry.instance.resolve<StatusPort>();

    // 1. 批量改物品状态
    if (itemIds.isNotEmpty) {
      await itemPort.bulkUpdateStatus(itemIds: itemIds, status: to);
    }

    // 2. 删除源状态
    await statusPort.delete(from);
  }
}