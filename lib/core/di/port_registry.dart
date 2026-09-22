/// 模块：core / di
/// 职责：全局端口注册中心，所有模块间通信的唯一入口。
/// 依赖：同级的 utils/app_logger.dart。
/// 约束：
///   1. 每个模块只能注册自己声明的 Port，不得注册其他模块的 Port。
///   2. 端口一旦注册不可覆盖，重复注册抛错（防装配顺序错乱）。
///   3. 业务代码只能通过 `resolve<T>()` 获取端口，禁止直接依赖实现类。
///   4. 此文件不 import 任何 modules/ 下的内容，保持 core 纯净。
library;

import '../utils/app_logger.dart';

/// 全局端口注册中心。
///
/// 生命周期：应用启动时由 AppBootstrap 装配，与应用同生命周期。
/// 线程模型：Dart 单线程，无需锁。
/// 可变性：内部 _ports 会随注册增长，注册完成后只读。
class PortRegistry {
  PortRegistry._();

  /// 全局唯一实例。
  static final PortRegistry instance = PortRegistry._();

  /// 端口类型 -> 实现实例。
  ///
  /// key 必须是抽象 Port 类型（如 LocationPort），
  /// value 是具体实现（如 LocationPortImpl）。
  final Map<Type, Object> _ports = {};

  /// 注册一个端口实现。
  ///
  /// `T` 必须是抽象 Port 类型，`impl` 是其实现。
  /// 重复注册同一 `T` 会抛出 StateError，用于在启动阶段暴露装配错误。
  ///
  /// 副作用：写入 _ports 并输出一条 info 日志。
  void register<T extends Object>(T impl) {
    if (_ports.containsKey(T)) {
      throw StateError(
        '端口 $T 已注册。请检查 AppBootstrap 是否存在重复注册，'
        '或两个模块注册了同一个 Port。',
      );
    }
    _ports[T] = impl;
    AppLogger.info('PortRegistry', '已注册: $T');
  }

  /// 解析端口。
  ///
  /// 未注册时抛出 StateError，消息中提示检查装配顺序。
  /// 返回值一定是已注册的非空实例。
  T resolve<T extends Object>() {
    final impl = _ports[T];
    if (impl == null) {
      throw StateError(
        '端口 $T 未注册。请检查 AppBootstrap 的注册顺序，'
        '确保依赖模块先于被依赖模块注册。',
      );
    }
    return impl as T;
  }

  /// 仅供测试与启动日志使用：清空所有注册。
  ///
  /// 生产代码除了 bootstrap 日志外不要调用。
  void reset() => _ports.clear();

  /// 返回已注册的端口类型列表，供启动日志与调试使用。
  ///
  /// 只读快照，不修改内部状态。
  List<Type> get registeredTypes => List.unmodifiable(_ports.keys);
}