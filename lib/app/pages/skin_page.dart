/// 模块：app / pages / skin
/// 职责：皮肤选择页。
/// 约束：
///   1. 只决定色相，不干预亮度。
///   2. 亮度由外观（浅色/深色/跟随系统）控制，本页无关。
library;

import 'package:flutter/material.dart';

import '../../core/theme/skin_manager.dart';

class SkinPage extends StatefulWidget {
  const SkinPage({super.key});

  @override
  State<SkinPage> createState() => _SkinPageState();
}

class _SkinPageState extends State<SkinPage> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('皮肤')),
      body: ValueListenableBuilder<Skin>(
        valueListenable: SkinManager.instance,
        builder: (_, current, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '皮肤只决定色调，明暗由"外观"设置控制。'
                        '切换浅色/深色时，皮肤会自动适配亮度。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  for (final s in Skin.values)
                    _SkinTile(
                      skin: s,
                      selected: s == current,
                      isDark: isDark,
                      onTap: () async {
                        await SkinManager.instance.setSkin(s);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已切换到「${s.label}」'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  final Skin skin;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _SkinTile({
    required this.skin,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 预览背景：跟随当前外观亮度。
    final previewBg =
        isDark ? skin.previewDark : skin.previewLight;
    // 预览主色：从 seed 生成。
    final previewPrimary = ColorScheme.fromSeed(
      seedColor: skin.seedColor,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: previewBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? previewPrimary
                : Colors.grey.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: previewPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: previewPrimary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    skin.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: previewPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: previewPrimary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}