import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/ai/ai_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/ai/models/ai_models.dart';

/// 人物分组：预览、改名、合并、删除与重新聚类。
class AiPersonsTab extends ConsumerStatefulWidget {
  const AiPersonsTab({super.key});

  @override
  ConsumerState<AiPersonsTab> createState() => _AiPersonsTabState();
}

class _AiPersonsTabState extends ConsumerState<AiPersonsTab> {
  /// 合并模式下被选中的分组 ID。
  final Set<String> _selected = <String>{};
  bool _mergeMode = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(aiPersonsProvider);
    final settings = ref.watch(opsSettingsControllerProvider);
    final client = ref.read(aiApiClientProvider);

    return Padding(
      padding: const EdgeInsets.all(AppDimens.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(aiPersonsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新'),
                style: _buttonStyle,
              ),
              OutlinedButton.icon(
                onPressed: () => _recluster(reset: false),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: const Text('增量聚类（保留现有人物）'),
                style: _buttonStyle,
              ),
              OutlinedButton.icon(
                onPressed: () => _recluster(reset: true),
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('重新聚类（清空分组）'),
                style: _buttonStyle,
              ),
              if (_selected.length >= 2)
                ElevatedButton.icon(
                  onPressed: _mergeSelected,
                  icon: const Icon(Icons.merge_rounded, size: 16),
                  label: Text('合并所选 ${_selected.length} 组'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_selected.isNotEmpty)
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('取消选择'),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '点击卡片选中后可将多个分组合并；增量聚类只处理尚未归属的人脸，'
            '不会影响已命名的人物。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppDimens.spacingS),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              data: (persons) {
                if (persons.isEmpty) {
                  return const Center(
                    child: Text('暂无人物分组。请先处理人脸能力，再执行增量聚类。'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('共 ${persons.length} 组',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppDimens.spacingXS),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: persons.length,
                        itemBuilder: (context, index) {
                          final person = persons[index];
                          return _PersonCard(
                            person: person,
                            thumbUrl: person.coverMediaId == null
                                ? null
                                : client.thumbUrl(settings, person.coverMediaId!),
                            selected: _selected.contains(person.id),
                            mergeMode: _mergeMode || _selected.isNotEmpty,
                            onTap: () => _toggle(person),
                            onRename: () => _rename(person),
                            onDelete: () => _delete(person),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static final _buttonStyle = OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    visualDensity: VisualDensity.compact,
  );

  void _toggle(AiPerson person) {
    setState(() {
      _mergeMode = true;
      if (!_selected.remove(person.id)) {
        _selected.add(person.id);
      }
      if (_selected.isEmpty) _mergeMode = false;
    });
  }

  Future<void> _rename(AiPerson person) async {
    final controller = TextEditingController(text: person.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('命名人物'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '例如：家人 / 朋友 / 昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null) return;

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    try {
      await client.renamePerson(settings, person.id, name: name);
      ref.invalidate(aiPersonsProvider);
    } catch (e) {
      _toast('命名失败: $e');
    }
  }

  Future<void> _delete(AiPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除该人物分组？'),
        content: const Text('分组内的人脸会回到未分配状态，媒体文件与标签不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    try {
      await client.deletePerson(settings, person.id);
      _selected.remove(person.id);
      ref.invalidate(aiPersonsProvider);
    } catch (e) {
      _toast('删除失败: $e');
    }
  }

  Future<void> _mergeSelected() async {
    final persons =
        ref.read(aiPersonsProvider).valueOrNull ?? const <AiPerson>[];
    final chosen = persons.where((p) => _selected.contains(p.id)).toList();
    if (chosen.length < 2) return;

    final targetId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('合并到哪个人物？'),
        children: [
          for (final person in chosen)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(person.id),
              child: Text('${person.displayName}（${person.faceCount} 张）'),
            ),
        ],
      ),
    );
    if (targetId == null) return;

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    try {
      final moved = await client.mergePersons(
        settings,
        sourceIds: chosen.map((p) => p.id).where((id) => id != targetId).toList(),
        targetId: targetId,
      );
      setState(_selected.clear);
      ref.invalidate(aiPersonsProvider);
      _toast('已合并 $moved 张人脸');
    } catch (e) {
      _toast('合并失败: $e');
    }
  }

  Future<void> _recluster({required bool reset}) async {
    if (reset) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('重新聚类会清空全部分组'),
          content: const Text(
            '现有的人物分组与人工命名都会被删除，随后按人脸特征重新分组。\n'
            '如果只是想归并新的人脸，请使用"增量聚类"。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认清空并重聚'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final client = ref.read(aiApiClientProvider);
    final settings = ref.read(opsSettingsControllerProvider);
    _toast('正在聚类，请稍候…');
    try {
      final result = await client.recluster(settings, reset: reset);
      ref.invalidate(aiPersonsProvider);
      _toast(
        '聚类完成：归入 ${result['assigned'] ?? 0} 张，'
        '新建 ${result['new_person'] ?? 0} 组，'
        '暂未成组 ${result['pending'] ?? 0} 张',
      );
    } catch (e) {
      _toast('聚类失败: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PersonCard extends StatelessWidget {
  final AiPerson person;
  final String? thumbUrl;
  final bool selected;
  final bool mergeMode;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _PersonCard({
    required this.person,
    required this.thumbUrl,
    required this.selected,
    required this.mergeMode,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.borderRadius),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: mergeMode ? onTap : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbUrl == null
                  ? const ColoredBox(
                      color: AppColors.surfaceVariant,
                      child: Icon(Icons.person_outline, size: 32),
                    )
                  : Image.network(
                      thumbUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceVariant,
                        child: Icon(Icons.broken_image_outlined, size: 24),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.paddingS,
                vertical: 6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          person.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle,
                            size: 14, color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.faceCount} 张',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: onRename,
                        icon: const Icon(Icons.edit_rounded, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        tooltip: '命名',
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 26,
                          minHeight: 26,
                        ),
                        tooltip: '删除分组',
                      ),
                    ],
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
