import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
import 'package:northstar/application/ops/providers/task_profiles_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';
import 'package:northstar/ui/ops/widgets/task_editor_dialog.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _apiBaseUrlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _intervalController = TextEditingController();

  bool _dirty = false;
  String _syncedToken = '';

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _apiKeyController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(opsSettingsControllerProvider);
    final settingsController = ref.read(opsSettingsControllerProvider.notifier);
    final tasks = ref.watch(taskProfilesControllerProvider);
    final taskController = ref.read(taskProfilesControllerProvider.notifier);

    _syncControllersIfNeeded(settings);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '设置'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('接口设置', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiBaseUrlController,
                          decoration: const InputDecoration(
                            labelText: 'API Base URL',
                            hintText: 'http://127.0.0.1:7275',
                          ),
                          onChanged: (_) {
                            _dirty = true;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _apiKeyController,
                          obscureText: settings.hideApiKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            suffixIcon: IconButton(
                              tooltip: settings.hideApiKey ? '显示' : '隐藏',
                              onPressed: () async {
                                await settingsController.update(
                                  hideApiKey: !settings.hideApiKey,
                                );
                              },
                              icon: Icon(
                                settings.hideApiKey
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            _dirty = true;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _intervalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '自动刷新间隔(秒)'),
                          onChanged: (_) {
                            _dirty = true;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final parsedSeconds =
                                    int.tryParse(_intervalController.text.trim()) ?? 10;
                                final safeSeconds = parsedSeconds < 3
                                    ? 3
                                    : (parsedSeconds > 3600 ? 3600 : parsedSeconds);
                                await settingsController.update(
                                  apiBaseUrl: _apiBaseUrlController.text.trim(),
                                  apiKey: _apiKeyController.text.trim(),
                                  autoRefreshSeconds: safeSeconds,
                                );
                                _dirty = false;
                                _syncedToken = _buildToken(ref.read(opsSettingsControllerProvider));
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('设置已保存')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('保存设置'),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '当前: ${settings.autoRefreshSeconds}s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spacingL),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.paddingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('任务配置管理', style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final created = await showDialog<TaskProfile>(
                                  context: context,
                                  builder: (_) => const TaskEditorDialog(),
                                );
                                if (created != null) {
                                  await taskController.upsertTask(created);
                                }
                              },
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('新增任务'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (tasks.isEmpty)
                          const Text('暂无任务')
                        else
                          for (final task in tasks)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(task.name),
                              subtitle: Text(
                                task.executablePath.isEmpty ? '(未设置exe路径)' : task.executablePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    tooltip: '编辑',
                                    onPressed: () async {
                                      final updated = await showDialog<TaskProfile>(
                                        context: context,
                                        builder: (_) => TaskEditorDialog(initial: task),
                                      );
                                      if (updated != null) {
                                        await taskController.upsertTask(updated);
                                      }
                                    },
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('删除任务'),
                                          content: Text('确认删除 ${task.name} 吗？'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: const Text('取消'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: const Text('删除'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        await taskController.removeTask(task.id);
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _syncControllersIfNeeded(OpsSettings settings) {
    final token = _buildToken(settings);
    if (_dirty || token == _syncedToken) {
      return;
    }

    _apiBaseUrlController.text = settings.apiBaseUrl;
    _apiKeyController.text = settings.apiKey;
    _intervalController.text = settings.autoRefreshSeconds.toString();
    _syncedToken = token;
  }

  String _buildToken(OpsSettings settings) {
    return '${settings.apiBaseUrl}|${settings.apiKey}|${settings.autoRefreshSeconds}|${settings.hideApiKey}';
  }
}
