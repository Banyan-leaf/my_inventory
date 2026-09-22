/// 模块：app / pages / dashboard / widgets
/// 职责：即将到期 / 已过期列表。
library;

import 'package:flutter/material.dart';

import '../../../../modules/stats/domain/entities/stats_data.dart';

class ExpiryList extends StatelessWidget {
  final List<ExpiryItem> items;
  const ExpiryList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _empty('30 天内无到期物品');
    }

    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (final e in items.take(15)) _row(e),
        ],
      ),
    );
  }

  Widget _row(ExpiryItem e) {
    final isExpired = e.daysLeft < 0;
    final isUrgent = !isExpired && e.daysLeft <= 7;
    final color = isExpired
        ? Colors.red
        : isUrgent
            ? Colors.orange
            : Colors.blueGrey;

    final kindText = e.kind == 'warranty' ? '保修' : '过期';
    final dueText =
        '${e.dueDate.year}-${e.dueDate.month.toString().padLeft(2, '0')}-${e.dueDate.day.toString().padLeft(2, '0')}';
    final leftText = isExpired ? '已过期 ${-e.daysLeft} 天' : '剩余 ${e.daysLeft} 天';

    return ListTile(
      dense: true,
      leading: Icon(
        isExpired ? Icons.error_outline : Icons.access_time,
        color: color,
        size: 20,
      ),
      title: Text(e.name, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
        '$kindText · 到期 $dueText',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Text(
        leftText,
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  Widget _empty(String text) {
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 80,
        child: Center(
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}