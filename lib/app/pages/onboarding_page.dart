/// 模块：app / pages / onboarding
/// 职责：新手指引。15 页详细引导，介绍软件所有功能。
/// 约束：
///   1. 主页面负责渲染和翻页逻辑。
///   2. 内容定义在 onboarding_content.dart 里。
///   3. 支持多种 Block 类型：标题、段落、列表、表格、提示、动手试试。
library;

import 'package:flutter/material.dart';

import 'onboarding_content.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_current < onboardingSteps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_current > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = onboardingSteps.length;
    final isLast = _current == total - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('新手指引 (${_current + 1}/$total)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('跳过'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部进度条
          LinearProgressIndicator(
            value: (_current + 1) / total,
            minHeight: 3,
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _current = i),
              itemCount: total,
              itemBuilder: (_, i) => _buildStep(onboardingSteps[i]),
            ),
          ),
          _buildBottomBar(isLast),
        ],
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: step.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(step.icon, size: 44, color: step.color),
            ),
          ),
          const SizedBox(height: 16),
          // 标题
          Center(
            child: Text(
              step.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: step.color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          // 副标题
          Center(
            child: Text(
              step.subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // 内容块
          for (final block in step.blocks) _buildBlock(block, step.color),
        ],
      ),
    );
  }

  Widget _buildBlock(Block block, Color accent) {
    switch (block) {
      case HeadingBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

      case ParagraphBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        );

      case BulletsBlock(:final items):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );

      case TableBlock(:final rows):
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Table(
              border: TableBorder.symmetric(
                inside: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1.4)},
              children: [
                for (var i = 0; i < rows.length; i++)
                  TableRow(
                    decoration: i == 0
                        ? BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                          )
                        : null,
                    children: [
                      for (final cell in rows[i])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            cell,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: i == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );

      case QuoteBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: Colors.grey[400]!, width: 3),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        );

      case TipBlock(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );

      case ActionBlock(:final title, :final steps):
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.teal.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      size: 18,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${i + 1}.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            steps[i],
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
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
  }

  Widget _buildBottomBar(bool isLast) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            if (_current > 0)
              TextButton.icon(
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('上一步'),
                onPressed: _prev,
              )
            else
              const SizedBox.shrink(),
            const Spacer(),
            // 圆点指示器
            Row(
              children: [
                for (var i = 0; i < onboardingSteps.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _current ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _current
                          ? onboardingSteps[_current].color
                          : Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
              label: Text(isLast ? '开始使用' : '下一步'),
              onPressed: _next,
            ),
          ],
        ),
      ),
    );
  }
}