/// 模块：app / pages / widgets
/// 职责：从状态列表中选择一个状态。返回状态 key。
library;

import 'package:flutter/material.dart';

import '../../../core/di/port_registry.dart';
import '../../../modules/status/domain/ports/status_port.dart';

/// 用户取消的返回值。
const String kStatusPickCancelled = '__cancelled__';

/// 展示状态选择对话框。
///
/// [title] 标题文本。
/// 返回选中的状态 key；用户取消时返回 [kStatusPickCancelled]。
Future<String> showPickStatusDialog(
  BuildContext context, {
  String title = '选择状态',
  String? currentKey,
}) async {
  final port = PortRegistry.instance.resolve<StatusPort>();
  final list = await port.all();
  if (!context.mounted) return kStatusPickCancelled;

  final result = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          for (final s in list)
            ListTile(
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _parseColor(s.color),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(s.label),
              subtitle: Text(
                s.key,
                style: const TextStyle(fontSize: 11),
              ),
              trailing: s.key == currentKey
                  ? const Icon(Icons.check, color: Colors.teal)
                  : null,
              onTap: () => Navigator.pop(ctx, s.key),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  return result ?? kStatusPickCancelled;
}

Color _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return Colors.grey;
  return Color(0xFF000000 | value);
}