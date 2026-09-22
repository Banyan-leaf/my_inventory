/// 模块：app / pages / dashboard / widgets
/// 职责：标签分布排行。每行用标签自定义颜色展示。
library;

import 'package:flutter/material.dart';

import '../../../../modules/stats/domain/entities/stats_data.dart';

class TagRanking extends StatelessWidget {
  final List<TagSlice> slices;
  const TagRanking({super.key, required this.slices});

  /// 进度条固定宽度。
  static const double _barWidth = 100;

  /// 数字固定宽度。
  static const double _countWidth = 32;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return _empty('暂无标签数据');
    }

    final max = slices.first.count;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 提示：多对多关系
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '一个物品可挂多个标签，各标签计数之和 ≥ 物品总数',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final s in slices.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 颜色圆点
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _parseColor(s.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 标签名：自适应宽度
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 进度条
                    SizedBox(
                      width: _barWidth,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: max == 0 ? 0 : s.count / max,
                          minHeight: 14,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(
                            _parseColor(s.color),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 数字
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
            if (slices.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '（仅显示前 10 个，共 ${slices.length} 个标签）',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return Colors.grey;
    return Color(0xFF000000 | value);
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