/// 模块：core / refresh
/// 职责：全局数据刷新通知器。
/// 约束：
///   1. 任何数据变更方调 bump()，监听方自行重新加载。
///   2. 各页面在 initState 注册监听，dispose 移除。
///   3. 不引入 Provider / Riverpod 等重型方案，保持轻量。
library;

import 'package:flutter/foundation.dart';

/// 全局刷新通知器。
///
/// 每次 bump() 使 value +1，通知所有监听方。
/// 监听方只关心"变了"，不关心变了多少次。
class AppRefresh extends ValueNotifier<int> {
  AppRefresh._() : super(0);

  /// 全局唯一实例。
  static final AppRefresh instance = AppRefresh._();

  /// 触发一次全局刷新通知。
  ///
  /// 幂等：连续多次调用会累积，每次监听方都会收到。
  void bump() => value++;
}