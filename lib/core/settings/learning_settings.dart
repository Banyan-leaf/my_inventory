/// 模块：core / settings
/// 职责：学习提醒的开关状态，持久化到 shared_preferences。
library;

import 'package:shared_preferences/shared_preferences.dart';

class LearningSettings {
  LearningSettings._();

  static const String _key = 'learn_prompt_enabled';

  /// 读取开关。默认开启。
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  /// 写入开关。
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}