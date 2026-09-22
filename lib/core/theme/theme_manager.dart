/// 模块：core / theme
/// 职责：全局主题管理器。管理明暗模式选择并持久化。
/// 约束：
///   1. 用 ValueNotifier 通知 UI 重建。
///   2. 持久化到 shared_preferences。
///   3. 第一次启动默认为跟随系统。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题管理器。
///
/// 单例，生命周期与应用一致。
class ThemeManager extends ValueNotifier<ThemeMode> {
  ThemeManager._() : super(ThemeMode.system);

  static final ThemeManager instance = ThemeManager._();

  /// 存储 key。
  static const String _prefKey = 'theme_mode';

  /// 从持久化存储加载。应用启动时调用一次。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    switch (saved) {
      case 'light':
        value = ThemeMode.light;
        break;
      case 'dark':
        value = ThemeMode.dark;
        break;
      default:
        value = ThemeMode.system;
    }
  }

  /// 设置并持久化。
  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _serialize(mode));
  }

  String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// 当前模式的显示名。
  String get label {
    switch (value) {
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
      case ThemeMode.system:
        return '跟随系统';
    }
  }
}