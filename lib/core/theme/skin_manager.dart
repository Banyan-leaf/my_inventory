/// 模块：core / theme
/// 职责：皮肤管理器。管理配色方案并持久化。
/// 约束：
///   1. 皮肤只决定 seed color，不干预亮度。
///   2. 亮度由 ThemeMode 决定，M3 自动为 light/dark 生成两套配色。
///   3. 与 ThemeManager 平级，互不干扰。
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 皮肤定义。
///
/// seedColor 会被 Material 3 用于生成完整调色板。
/// 同一个 seed 在 light 和 dark 下会渲染出不同的亮度，
/// 因此不需要为每个皮肤准备两套色值。

///如果你有幸看到这行注释，欢迎关注东方project。

enum Skin {
  defaultTeal('默认青', Color(0xFF00897B)),
  reimuRed('灵梦红', Color(0xFFC62828)),
  ///赤 色 杀 人 魔
  sanaeGreen('早苗绿', Color(0xFF2E7D32)),
  ///教 你 画 星 星
  marisaYellow('莎莎黄', Color(0xFFFFC107)),
  ///金 发 小 女 孩（爱丽丝：？）
  patchouliPurple('姆Q紫', Color(0xFF6A1B9A)),
  ///不 动 的 大 图 书 馆
  kogasaBlue('小伞蓝', Color(0xFF87CEFA));
  ///一点都不吓人呢（笑）

  const Skin(this.label, this.seedColor);

  /// 显示名。
  final String label;

  /// M3 seed 色。
  final Color seedColor;

  /// 预览色：浅色模式下的近似背景色。
  ///
  /// 直接由 seed 生成，用于设置页色块预览。
  Color get previewLight =>
      ColorScheme.fromSeed(seedColor: seedColor).surfaceContainerHighest;

  /// 预览色：深色模式下的近似背景色。
  Color get previewDark => ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).surfaceContainerHighest;
}

/// 皮肤管理器。
///
/// 生命周期：应用启动时 load()，与 App 同生命周期。
class SkinManager extends ValueNotifier<Skin> {
  SkinManager._() : super(Skin.defaultTeal);

  static final SkinManager instance = SkinManager._();

  static const String _prefKey = 'skin';

  /// 从持久化存储加载。
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    if (name == null) return;
    for (final s in Skin.values) {
      if (s.name == name) {
        value = s;
        return;
      }
    }
  }

  /// 设置并持久化。
  Future<void> setSkin(Skin skin) async {
    value = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, skin.name);
  }
}