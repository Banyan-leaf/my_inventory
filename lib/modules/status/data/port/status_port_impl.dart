/// 模块：status / data / port
/// 职责：StatusPort 的实现。
library;

import 'package:sqflite/sqflite.dart';

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/item_status.dart';
import '../../domain/ports/status_port.dart';
import '../../domain/ports/status_repo.dart';

class StatusPortImpl implements StatusPort {
  final StatusRepo _repo;
  final Database _db;

  StatusPortImpl(this._repo, this._db);

  /// 6 个系统状态。
  static const List<({String key, String label, String color})> _systemStatuses = [
    (key: 'in_stock', label: '在库', color: '#26A69A'),
    (key: 'loaned', label: '借出', color: '#FFA726'),
    (key: 'repair', label: '维修', color: '#42A5F5'),
    (key: 'lost', label: '丢失', color: '#EF5350'),
    (key: 'discarded', label: '丢弃', color: '#9E9E9E'),
    (key: 'consumed', label: '耗尽', color: '#8D6E63'),
  ];

  /// Seed 系统状态（幂等）。
  Future<void> seedSystemStatuses() async {
    final existing = await _repo.count();
    if (existing > 0) return;
    for (var i = 0; i < _systemStatuses.length; i++) {
      final s = _systemStatuses[i];
      await _repo.insert(ItemStatus(
        key: s.key,
        label: s.label,
        color: s.color,
        isSystem: true,
        sortOrder: i,
      ));
    }
  }

  @override
  Future<List<ItemStatus>> all() => _repo.findAll();

  @override
  Future<ItemStatus?> findByKey(String key) => _repo.findByKey(key);

  @override
  Future<void> create({
    required String key,
    required String label,
    String? color,
  }) async {
    final k = key.trim().toLowerCase();
    final l = label.trim();
    if (!RegExp(r'^[a-z][a-z0-9_]{0,30}$').hasMatch(k)) {
      throw const ValidationException(
        'key 只允许小写字母、数字、下划线，且以字母开头',
      );
    }
    if (l.isEmpty) {
      throw const ValidationException('显示名不能为空');
    }
    if (await _repo.findByKey(k) != null) {
      throw ValidationException('状态 $k 已存在');
    }
    await _repo.insert(ItemStatus(
      key: k,
      label: l,
      color: color,
      isSystem: false,
      sortOrder: 1000,
    ));
  }

  @override
  Future<void> rename({required String key, required String newLabel}) async {
    final s = await _repo.findByKey(key);
    if (s == null) {
      throw NotFoundException('状态 $key 不存在');
    }
    final trimmed = newLabel.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('显示名不能为空');
    }
    await _repo.update(s.copyWith(label: trimmed));
  }

  @override
  Future<void> updateColor({required String key, String? color}) async {
    final s = await _repo.findByKey(key);
    if (s == null) {
      throw NotFoundException('状态 $key 不存在');
    }
    // 显式构造，因为 copyWith 无法把 color 置为 null。
    await _repo.update(ItemStatus(
      key: s.key,
      label: s.label,
      color: color,
      isSystem: s.isSystem,
      sortOrder: s.sortOrder,
    ));
  }

  @override
  Future<void> delete(String key) async {
    final s = await _repo.findByKey(key);
    if (s == null) {
      throw NotFoundException('状态 $key 不存在');
    }
    if (s.isSystem) {
      throw const ValidationException('系统状态不可删除，但可以改名');
    }
    await _repo.delete(key);
  }

  @override
  Future<bool> exists(String key) async {
    final s = await _repo.findByKey(key);
    return s != null;
  }

  @override
  Future<int> countItems(String statusKey) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM item '
      'WHERE status = ? AND deleted_at IS NULL',
      [statusKey],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}