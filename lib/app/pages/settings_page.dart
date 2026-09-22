/// 模块：app / pages / settings
/// 职责：设置页。目前只有导入导出功能。
library;

import 'package:flutter/material.dart';

import '../../core/di/port_registry.dart';
import '../../core/error/app_exception.dart';
import '../../modules/backup/domain/ports/backup_port.dart';
import '../../core/settings/learning_settings.dart';
import '../../core/theme/theme_manager.dart';
import 'category_page.dart';
import 'onboarding_page.dart';
import 'skin_page.dart';
import '../../core/theme/skin_manager.dart';
import 'tag_page.dart';
import 'status_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 学习提醒是否开启。
  bool _learnEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadLearningSetting();
  }

  Future<void> _loadLearningSetting() async {
    final v = await LearningSettings.isEnabled();
    if (!mounted) return;
    setState(() => _learnEnabled = v);
  }

  Future<void> _toggleLearning(bool value) async {
    await LearningSettings.setEnabled(value);
    if (!mounted) return;
    setState(() => _learnEnabled = value);
  }

  /// 弹菜单选择主题模式。
  Future<void> _chooseTheme() async {
    final current = ThemeManager.instance.value;
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择主题',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            _themeOption(ctx, ThemeMode.system, Icons.brightness_auto, '跟随系统', current),
            _themeOption(ctx, ThemeMode.light, Icons.light_mode, '浅色', current),
            _themeOption(ctx, ThemeMode.dark, Icons.dark_mode, '深色', current),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await ThemeManager.instance.setMode(selected);
  }

  Widget _themeOption(
    BuildContext ctx,
    ThemeMode mode,
    IconData icon,
    String label,
    ThemeMode current,
  ) {
    final selected = mode == current;
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.teal : null),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.teal : null,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: selected ? const Icon(Icons.check, color: Colors.teal) : null,
      onTap: () => Navigator.pop(ctx, mode),
    );
  }

  bool _busy = false;
  String _status = '';

  BackupPort get _port => PortRegistry.instance.resolve<BackupPort>();

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = '导出中...';
    });
    try {
      final dir = await _port.defaultDirectory();
      final name = _port.suggestedFileName();
      final path = '$dir\\$name';
      final info = await _port.export(path);
      if (!mounted) return;
      setState(() {
        _status = '已导出到：\n${info.filePath}\n'
            '${info.totalRows} 行 · ${(info.fileSize / 1024).toStringAsFixed(1)} KB';
      });
    } on AppException catch (e) {
      setState(() => _status = '导出失败: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ctrl = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从文件恢复'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '完整文件路径',
            hintText: r'C:\Users\...\inventory_backup_20260915_120000.json',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (path == null || path.trim().isEmpty) return;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 危险操作'),
        content: const Text(
            '恢复会清空当前所有数据并用备份文件覆盖，\n此操作不可撤销，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确定恢复'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _busy = true;
      _status = '恢复中...';
    });
    try {
      final result = await _port.restore(path.trim());
      if (!mounted) return;
      setState(() {
        _status = result.success
            ? '恢复成功：\n${result.tableCounts.entries.map((e) => '${e.key}: ${e.value}').join('\n')}'
            : '恢复失败: ${result.error}';
      });
    } catch (e) {
      setState(() => _status = '恢复失败: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined, color: Colors.teal),
              title: const Text('新手指引'),
              subtitle: const Text('15 页详细引导，从入门到进阶'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const OnboardingPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeManager.instance,
              builder: (_, mode, _) => ListTile(
                leading: Icon(
                  mode == ThemeMode.dark
                      ? Icons.dark_mode
                      : mode == ThemeMode.light
                          ? Icons.light_mode
                          : Icons.brightness_auto,
                ),
                title: const Text('外观'),
                subtitle: Text(ThemeManager.instance.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: _chooseTheme,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ValueListenableBuilder<Skin>(
              valueListenable: SkinManager.instance,
              builder: (_, skin, _) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: skin.seedColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                title: const Text('皮肤'),
                subtitle: Text(skin.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SkinPage(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.school_outlined),
              title: const Text('学习提醒'),
              subtitle: Text(
                _learnEnabled
                    ? '新建物品后询问是否加入词库'
                    : '已关闭，不会弹出学习对话框',
              ),
              value: _learnEnabled,
              onChanged: _toggleLearning,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('分类管理'),
                  subtitle: const Text('新增、重命名、删除物品分类'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: const Text('状态管理'),
                  subtitle: const Text('新增、重命名、删除物品状态'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StatusPage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: const Text('标签管理'),
                  subtitle: const Text('新增、编辑、删除物品标签'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TagPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: const Text('导出到 JSON'),
                  subtitle: const Text('保存到文档目录'),
                  onTap: _busy ? null : _export,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('从 JSON 恢复'),
                  subtitle: const Text('覆盖当前所有数据'),
                  onTap: _busy ? null : _restore,
                ),
              ],
            ),
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _status,
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}