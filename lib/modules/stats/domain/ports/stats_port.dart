/// 模块：stats / domain / ports
/// 职责：stats 模块对外契约。
/// 依赖：同模块 entities/stats_data.dart。
/// 约束：
///   1. 不直接访问任何业务表，全部经其他模块 Port 获取。
///   2. 输出纯数据结构，不含 UI 概念。
///   3. 业务模块不因 stats 而增加方法（listSnapshots 是通用只读接口）。
library;

import '../entities/stats_data.dart';

/// stats 模块对外端口。
abstract class StatsPort {
  /// 总览卡片。
  Future<Overview> overview();

  /// 分类分布。已按 count 降序。
  ///
  /// 无分类物品归入"未分类"。
  Future<List<CategorySlice>> categoryDistribution();

  /// 位置分布。已按 count 降序。
  ///
  /// 未指定位置的物品归入"未指定"。
  Future<List<LocationSlice>> locationDistribution();

  /// 状态分布。
  Future<List<StatusSlice>> statusDistribution();

  /// 价值随时间累积（按 purchaseDate 升序累加）。
  ///
  /// 无 purchaseDate 的物品不计入。
  Future<List<TimePoint>> valueTrend();

  /// 录入活跃度。按天聚合新建物品数。
  ///
  /// [days] 回溯天数，默认 30 天。
  Future<List<TimePoint>> intakeActivity({int days = 30});

  /// 即将到期 / 已过期。
  ///
  /// [withinDays] 天数阈值，默认 30 天。
  /// 同时包含保修到期（warranty）和过期日期（expiry）。
  Future<List<ExpiryItem>> expiringSoon({int withinDays = 30});

  /// 标签分布。已按关联物品数降序。
  ///
  /// 只返回有关联物品的标签。
  /// 注意：物品与标签是多对多，各标签计数之和 ≥ 物品总数。
  Future<List<TagSlice>> tagDistribution();
}