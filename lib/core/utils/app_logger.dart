/// 模块：core / utils
/// 职责：极简日志工具，零外部依赖。
/// 依赖：dart:developer（SDK 内置）。
/// 约束：
///   1. 不引入任何第三方日志库，保持轻量。
///   2. 生产环境可通过 setEnabled(false) 一键关闭。
///   3. debug 模式下同时输出到终端和 DevTools，便于排查。
library;

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// 全局日志工具。
///
/// 生命周期：无状态，全静态方法。
/// 线程模型：Dart 单线程事件循环，天然安全。
class AppLogger {
  AppLogger._();

  static bool _enabled = true;

  /// 全局开关。生产环境设为 false。
  static void setEnabled(bool value) => _enabled = value;

  /// 普通信息日志。
  static void info(String tag, String message) {
    if (!_enabled) return;
    developer.log(message, name: tag, level: 800);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag] $message');
    }
  }

  /// 警告日志。
  static void warn(String tag, String message, [Object? error]) {
    if (!_enabled) return;
    developer.log(message, name: tag, level: 900, error: error);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag][WARN] $message${error != null ? ' | $error' : ''}');
    }
  }

  /// 错误日志。
  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? st,
  ]) {
    if (!_enabled) return;
    developer.log(message, name: tag, level: 1000, error: error, stackTrace: st);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[$tag][ERROR] $message${error != null ? ' | $error' : ''}');
    }
  }
}