/// 模块：app / use_cases
/// 职责：从"未录入候选词"创建物品，并回写候选词状态。
/// 依赖：
///   - item 模块的 ItemPort、Item
///   - suggestion 模块的 SuggestionPort
///   - core/di/port_registry.dart
/// 约束：
///   1. 跨模块编排只在此层，domain 和 data 层各自不感知对方。
///   2. 失败处理：ItemPort.create 成功但 adopt 失败时，
///      物品已存在（视为成功），仅候选词状态未更新，
///      下次创建同名候选会被唯一索引拦下。
///      本地单用户场景可接受，不引入补偿机制。
library;

import '../../core/di/port_registry.dart';
import '../../modules/item/domain/entities/item.dart';
import '../../modules/item/domain/ports/item_port.dart';
import '../../modules/suggestion/domain/ports/suggestion_port.dart';

/// 从候选词创建物品的用例。
///
/// 生命周期：无状态，可重复实例化。
class CreateItemFromCandidateUseCase {
  /// 执行用例。
  ///
  /// [candidateId] 未录入候选词的主键。
  /// [name] 物品名称。通常等于候选词的 word，允许用户修改。
  /// [locationId] 可选位置。
  /// [categoryId] 可选分类。
  /// [quantity] 数量，默认 1。
  ///
  /// 返回新物品 id。
  /// 抛出 [NotFoundException] 当候选词不存在。
  /// 抛出 [ValidationException] 当 name 为空或外键不存在。
  Future<int> execute({
    required int candidateId,
    required String name,
    int? locationId,
    int? categoryId,
    double quantity = 1,
  }) async {
    final itemPort = PortRegistry.instance.resolve<ItemPort>();
    final suggestionPort = PortRegistry.instance.resolve<SuggestionPort>();

    // 1. 创建物品。内部会自动写入 stock_in 事件。
    final itemId = await itemPort.create(Item(
      name: name,
      locationId: locationId,
      categoryId: categoryId,
      quantity: quantity,
    ));

    // 2. 回写候选词的 item_id 与命中数。
    await suggestionPort.adopt(candidateId: candidateId, itemId: itemId);

    return itemId;
  }
}