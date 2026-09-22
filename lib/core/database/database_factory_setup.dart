/// 模块：core / database
/// 职责：根据运行平台初始化 sqflite 的 databaseFactory。
/// 依赖：sqflite、sqflite_common_ffi、dart:io。
/// 约束：
///   1. 所有平台差异集中在此文件，其他模块不感知平台。
///   2. 必须在 AppDatabase.open() 之前调用。
library;

import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 初始化数据库工厂。
///
/// 平台规则：
///   - Windows / Linux / macOS 桌面：使用 sqflite_common_ffi
///   - Android / iOS：使用 sqflite 自带的原生实现
///   - Web：当前阶段不支持，直接抛错
///
/// 幂等：多次调用无副作用。
void setupDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
  // Android / iOS 无需初始化，sqflite 默认可用。
  // Web 会在 AppDatabase.open() 时报错，后续需要时再接 sqflite_common_ffi_web。
}