/// 回顾预设的编辑/管理对话框。
///
/// 预设只存在后端（`/API/ai/review/presets`）：页面只做增删改的转发，
/// 绝不本地缓存一份，避免两端不一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/api/generated/api_contract.dart';
import 'package:torrid/features/review/providers/review_providers.dart';

/// 打开预设管理对话框。
Future<void> showReviewPresetManagerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ReviewPresetManagerDialog(),
  );
}

/// 预设管理：列表 + 新建/编辑/删除。
class ReviewPresetManagerDialog extends ConsumerWidget {
  const ReviewPresetManagerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewControllerProvider);
    final controller = ref.read(reviewControllerProvider.notifier);
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return AlertDialog(
      title: const Text('回顾预设', style: TextStyle(fontSize: 18)),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: _buildBody(context, ref, state, controller),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => showReviewPresetEditorDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('新建预设'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ReviewState state,
    ReviewController controller,
  ) {
    if (state.presets.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '还没有预设，或服务端不可达。',
              style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
            ),
          ),
          // 预设列表为空绝大多数情况是请求失败，给一个明确的重试入口
          OutlinedButton.icon(
            onPressed: state.loadingPresets
                ? null
                : () => controller.loadPresets(force: true),
            icon: state.loadingPresets
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: const Text('重新加载'),
          ),
        ],
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        for (final preset in state.presets)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    preset.name,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (preset.isDefault) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '默认',
                    style: TextStyle(fontSize: 11, color: AppTheme.primary),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '语气：${preset.tone}\n角色：${preset.role}',
              style: const TextStyle(fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '编辑',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      showReviewPresetEditorDialog(context, preset: preset),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  // 默认预设不允许删除（服务端同样会拒绝）
                  tooltip: preset.isDefault ? '默认预设不可删除' : '删除',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  onPressed: preset.isDefault
                      ? null
                      : () => _confirmDelete(context, controller, preset),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ReviewController controller,
    ReviewPreset preset,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除预设', style: TextStyle(fontSize: 17)),
        content: Text('确定删除预设「${preset.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除', style: TextStyle(color: AppTheme.errorVivid)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await controller.deletePreset(preset.id);
    if (error != null) {
      messenger?.showSnackBar(SnackBar(content: Text('删除失败：$error')));
    }
  }
}

/// 打开预设编辑器（[preset] 为空表示新建）。
Future<void> showReviewPresetEditorDialog(
  BuildContext context, {
  ReviewPreset? preset,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ReviewPresetEditorDialog(preset: preset),
  );
}

/// 预设编辑器：名称 + 语气 + 角色 + 设为默认。
class ReviewPresetEditorDialog extends ConsumerStatefulWidget {
  const ReviewPresetEditorDialog({super.key, this.preset});

  final ReviewPreset? preset;

  @override
  ConsumerState<ReviewPresetEditorDialog> createState() =>
      _ReviewPresetEditorDialogState();
}

class _ReviewPresetEditorDialogState
    extends ConsumerState<ReviewPresetEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _toneController;
  late final TextEditingController _roleController;

  late bool _isDefault;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final preset = widget.preset;
    _nameController = TextEditingController(text: preset?.name ?? '');
    _toneController = TextEditingController(text: preset?.tone ?? '');
    _roleController = TextEditingController(text: preset?.role ?? '');
    _isDefault = preset?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _toneController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.preset == null;

    return AlertDialog(
      title: Text(isNew ? '新建预设' : '编辑预设', style: const TextStyle(fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '例如：平实记录',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _toneController,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '语气',
                hintText: '例如：平实、克制，不夸张不煽情',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _roleController,
              enabled: !_saving,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '角色',
                hintText: '例如：熟悉我日常节奏的记录者',
                isDense: true,
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('设为默认预设', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                '默认预设用于未指定预设的回顾；原默认预设会被取消标记。',
                style: TextStyle(fontSize: 11),
              ),
              value: _isDefault,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _isDefault = value),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.errorVivid,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '名称不能为空');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await ref.read(reviewControllerProvider.notifier).savePreset(
          id: widget.preset?.id,
          name: name,
          tone: _toneController.text.trim(),
          role: _roleController.text.trim(),
          isDefault: _isDefault,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }
}
