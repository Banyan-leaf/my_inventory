/// 模块：app / pages / dashboard / widgets
/// 职责：位置分布排行。用进度条自绘，不依赖 fl_chart。
/// 约束：
///   1. 位置名占自适应宽度，最多 2 行，超出省略。
///   2. 进度条与数字占固定宽度，保证对齐。
library;

import 'package:flutter/material.dart';

import '../../../../modules/stats/domain/entities/stats_data.dart';

class LocationRanking extends StatelessWidget {
  final List<LocationSlice> slices;
  const LocationRanking({super.key, required this.slices});

  /// 进度条固定宽度。
  static const double _barWidth = 100;

  /// 数字固定宽度。
  static const double _countWidth = 32;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return _empty('暂无位置数据');
    }

    final max = slices.first.count; // 已按降序

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final s in slices.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 位置名：自适应宽度，最多两行
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 进度条：固定宽度
                    SizedBox(
                      width: _barWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : s.count / max,
                          minHeight: 14,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF26A69A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 数字：固定宽度，右对齐
                    SizedBox(
                      width: _countWidth,
                      child: Text(
                        '${s.count}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String text) {
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