/// 模块：core / database
/// 职责：SQLite 连接管理 + 全库建表脚本集中声明。
/// 依赖：sqflite、path、path_provider、同级的 error 与 utils。
/// 约束：
///   1. 不含任何业务逻辑，只负责连接与 schema。
///   2. 所有模块的建表 SQL 集中在此，便于一眼看到完整 schema。
library;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../error/app_exception.dart';
import '../utils/app_logger.dart';

/// 应用数据库。
class AppDatabase {
  /// 当前 schema 版本。任何表结构变更都必须 +1。
  ///
  /// v1: location / category / tag
  /// v2: + event
  /// v3: + item
  /// v4: + attachment
  /// v5: + candidate（suggestion 模块）
  static const int schemaVersion = 12;

  final Database _db;

  AppDatabase._(this._db);

  /// 打开（或创建）数据库。
  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'inventory.db');

    try {
      final db = await openDatabase(
        path,
        version: schemaVersion,
        onCreate: (db, version) async {
          AppLogger.info('AppDatabase', '创建数据库 schema v$version');
          for (final sql in _schema) {
            await db.execute(sql);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          AppLogger.warn(
            'AppDatabase',
            'schema $oldVersion -> $newVersion，重建所有表',
          );
          for (final sql in _dropAll) {
            await db.execute(sql);
          }
          for (final sql in _schema) {
            await db.execute(sql);
          }
        },
      );
      AppLogger.info('AppDatabase', '数据库已打开: $path');
      return AppDatabase._(db);
    } catch (e, st) {
      AppLogger.error('AppDatabase', '打开数据库失败', e, st);
      throw AppDatabaseException('打开数据库失败', cause: e);
    }
  }

  /// 底层 Database 实例。只允许 data 层引用。
  Database get raw => _db;

  Future<void> close() => _db.close();

  /// 全库建表脚本。表按模块分组。
  static const List<String> _schema = [
    // ============ location 模块 ============
    '''
    CREATE TABLE location (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      parent_id INTEGER REFERENCES location(id) ON DELETE SET NULL,
      type TEXT NOT NULL DEFAULT 'room',
      note TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE INDEX idx_location_parent ON location(parent_id)',

    // ============ status 模块 ============
    '''
    CREATE TABLE item_status (
      key TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      color TEXT,
      is_system INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',

    // ============ category 模块 ============
    '''
    CREATE TABLE category (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      parent_id INTEGER REFERENCES category(id) ON DELETE SET NULL,
      icon TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE INDEX idx_category_parent ON category(parent_id)',

    // ============ tag 模块 ============
    '''
    CREATE TABLE tag (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      color TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',

    // ============ event 模块 ============
    '''
    CREATE TABLE event (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      type TEXT NOT NULL,
      event_date TEXT NOT NULL,
      from_location_id INTEGER,
      to_location_id INTEGER,
      person_id INTEGER,
      quantity REAL,
      due_date TEXT,
      note TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE INDEX idx_event_item ON event(item_id)',
    'CREATE INDEX idx_event_date ON event(event_date)',
    'CREATE INDEX idx_event_type ON event(type)',

    // ============ item 模块 ============
    '''
    CREATE TABLE item (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      aliases TEXT,
      category_id INTEGER,
      location_id INTEGER,
      quantity REAL NOT NULL DEFAULT 1,
      unit TEXT NOT NULL DEFAULT '件',
      status TEXT NOT NULL DEFAULT 'in_stock',
      purchase_date TEXT,
      price REAL,
      currency TEXT NOT NULL DEFAULT 'CNY',
      warranty_until TEXT,
      expiry_date TEXT,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT
    )
    ''',
    'CREATE INDEX idx_item_name ON item(name)',
    'CREATE INDEX idx_item_location ON item(location_id)',
    'CREATE INDEX idx_item_category ON item(category_id)',
    'CREATE INDEX idx_item_status ON item(status)',
    'CREATE INDEX idx_item_expiry ON item(expiry_date)',
    'CREATE INDEX idx_item_deleted ON item(deleted_at)',

    // ============ attachment 模块 ============
    '''
    CREATE TABLE attachment (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      event_id INTEGER,
      file_path TEXT NOT NULL,
      mime_type TEXT,
      file_size INTEGER,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE INDEX idx_attachment_item ON attachment(item_id)',
    'CREATE INDEX idx_attachment_event ON attachment(event_id)',

    // ============ suggestion 模块 ============
    '''
    CREATE TABLE candidate (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT NOT NULL,
      normalized TEXT NOT NULL,
      source TEXT NOT NULL DEFAULT 'user',
      group_name TEXT NOT NULL DEFAULT 'other',
      item_id INTEGER,
      hit_count INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE UNIQUE INDEX idx_candidate_norm_group ON candidate(normalized, group_name)',
    'CREATE INDEX idx_candidate_item ON candidate(item_id)',
    'CREATE INDEX idx_candidate_group ON candidate(group_name)',

    // ============ suggestion 模块：多对多关联 ============
    '''
    CREATE TABLE candidate_item (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      candidate_id INTEGER NOT NULL,
      item_id INTEGER NOT NULL,
      linked_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',
    'CREATE UNIQUE INDEX idx_candidate_item_unique ON candidate_item(candidate_id, item_id)',
    'CREATE INDEX idx_candidate_item_cand ON candidate_item(candidate_id)',
    'CREATE INDEX idx_candidate_item_item ON candidate_item(item_id)',

    // ============ suggestion 模块：大类字典 ============
    '''
    CREATE TABLE candidate_group (
      key TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      is_system INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    ''',

    // ============ tag 模块：物品-标签多对多 ============
    '''
    CREATE TABLE item_tag (
      item_id INTEGER NOT NULL,
      tag_id INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (item_id, tag_id)
    )
    ''',
    'CREATE INDEX idx_item_tag_tag ON item_tag(tag_id)',
  ];

  /// 逆序 DROP 所有表。只在 onUpgrade 中使用。
  static const List<String> _dropAll = [
    'DROP TABLE IF EXISTS item_tag',
    'DROP TABLE IF EXISTS candidate_group',
    'DROP TABLE IF EXISTS candidate_item',
    'DROP TABLE IF EXISTS candidate',
    'DROP TABLE IF EXISTS attachment',
    'DROP TABLE IF EXISTS item',
    'DROP TABLE IF EXISTS event',
    'DROP TABLE IF EXISTS tag',
    'DROP TABLE IF EXISTS category',
    'DROP TABLE IF EXISTS item_status',
    'DROP TABLE IF EXISTS location',
  ];
}