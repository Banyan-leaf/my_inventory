/// 模块：app
/// 职责：应用启动装配，按依赖顺序注册所有模块。
library;

import '../core/database/app_database.dart';
import '../core/di/port_registry.dart';
import '../core/utils/app_logger.dart';
import '../modules/attachment/attachment_module.dart';
import '../modules/backup/backup_module.dart';
import '../modules/category/category_module.dart';
import '../modules/event/event_module.dart';
import '../modules/item/item_module.dart';
import '../modules/location/location_module.dart';
import '../modules/stats/stats_module.dart';
import '../modules/status/status_module.dart';
import '../modules/suggestion/suggestion_module.dart';
import '../modules/tag/tag_module.dart';

Future<AppDatabase> bootstrap() async {
  AppLogger.info('Bootstrap', '开始装配');

  final db = await AppDatabase.open();

  LocationModule.register(db);
  CategoryModule.register(db);
  TagModule.register(db);
  EventModule.register(db);
  await StatusModule.register(db);
  ItemModule.register(db);
  AttachmentModule.register(db);
  await SuggestionModule.register(db);
  StatsModule.register(db);
  BackupModule.register(db);

  AppLogger.info(
    'Bootstrap',
    '装配完成，已注册端口: ${PortRegistry.instance.registeredTypes}',
  );

  return db;
}