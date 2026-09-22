/// 模块：app / pages / dashboard / widgets
/// 职责：状态分布环形图 + 图例。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../modules/stats/domain/entities/stats_data.dart';

class StatusPie extends StatelessWidget {
  final List<StatusSlice> slices;
  const StatusPie({super.key, required this.slices});

  static const Map<String, Color> _colorByStatus = {
    'in_stock': Color(0xFF26A69A),
    'loaned': Color(0xFFFFA726),
    'repair': Color(0xFF42A5F5),
    'lost': Color(0xFFEF5350),
    'discarded': Color(0xFF9E9E9E),
    'consumed': Color(0xFF8D6E63),
  };

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const _EmptyBox(text: '暂无状态数据');
    }

    final total = slices.fold<int>(0, (s, e) => s + e.count);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.count.toDouble(),
                        color: _colorByStatus[s.status] ?? Colors.grey,
                        title: total == 0
                            ? ''
                            : '${(s.count * 100 ~/ total)}%',
                        radius: 45,
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final s in slices)
                  _LegendItem(
                    color: _colorByStatus[s.status] ?? Colors.grey,
                    text: '${s.label} (${s.count})',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: SizedBox(
        height: 100,
        child: Center(
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}