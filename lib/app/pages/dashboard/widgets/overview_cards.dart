/// 模块：app / pages / dashboard / widgets
/// 职责：总览卡片 2x2 网格。
library;

import 'package:flutter/material.dart';

import '../../../../modules/stats/domain/entities/stats_data.dart';

class OverviewCards extends StatelessWidget {
  final Overview data;
  const OverviewCards({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        _Card(
          label: '物品总数',
          value: '${data.totalItems}',
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
        ),
        _Card(
          label: '总价值 (CNY)',
          value: data.totalValue.toStringAsFixed(0),
          icon: Icons.attach_money,
          color: Colors.indigo,
        ),
        _Card(
          label: '借出中',
          value: '${data.loanedCount}',
          icon: Icons.outbox_outlined,
          color: Colors.orange,
        ),
        _Card(
          label: '即将到期',
          value: '${data.expiringSoonCount}',
          icon: Icons.warning_amber_outlined,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Card({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}