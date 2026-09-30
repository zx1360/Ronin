import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/chat/models/review_models.dart';
import 'package:torrid/features/chat/providers/review_providers.dart';

/// 角色与语气预设的编辑页。
///
/// 服务端 `<STATIC_DIR>/data/review_presets.json` 是权威：这里的"保存"把整份列表
/// 推送到服务端（整体替换），成功后本地镜像才更新；失败则两份都保持原样。
class ReviewPresetsPage extends ConsumerStatefulWidget {
  const ReviewPresetsPage({super.key});

  @override
  ConsumerState<ReviewPresetsPage> createState() => _ReviewPresetsPageState();
}

class _ReviewPresetsPageState extends ConsumerState<ReviewPresetsPage> {
  /// 正在编辑的副本（未保存前不写 Hive，也不推送）。
  List<ReviewPreset>? _draft;

  List<ReviewPreset> _current(ReviewPresetsState state) =>
      _draft ?? List.of(state.presets);

  bool _dirty(ReviewPresetsState state) {
    final draft = _draft;
    if (draft == null) return false;
    if (draft.length != state.presets.length) return true;
    for (var i = 0; i < draft.length; i++) {
      final a = draft[i];
      final b = state.presets[i];
      if (a.id != b.id ||
          a.name != b.name ||
          a.role != b.role ||
          a.tone != b.tone) {
        return true;
      }
    }
    return false;
  }

  Future<void> _save(List<ReviewPreset> presets) async {
    for (final preset in presets) {
      final problem = preset.problem;
      if (problem != null) {
        _toast('「${preset.name.isEmpty ? '未命名' : preset.name}」$problem');
        return;
      }
    }
    final ok =
        await ref.read(reviewPresetsControllerProvider.notifier).save(presets);
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(reviewPresetsControllerProvider).error;
      _toast('保存失败，服务端与本地都未改动：$error');
      return;
    }
    setState(() => _draft = null);
    _toast('已保存到服务端');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _edit(int index, List<ReviewPreset> presets) async {
    final edited = await showModalBottomSheet<ReviewPreset>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PresetEditor(preset: presets[index]),
    );
    if (edited == null || !mounted) return;
    setState(() {
      final next = List.of(presets);
      next[index] = edited;
      _draft = next;
    });
  }

  /// 新增：先编辑再入草稿，取消时不留空壳。
  Future<void> _add(List<ReviewPreset> presets) async {
    final created = await showModalBottomSheet<ReviewPreset>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PresetEditor(preset: ReviewPreset.draft()),
    );
    if (created == null || !mounted) return;
    setState(() => _draft = [...presets, created]);
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewPresetsControllerProvider);
    final presets = _current(state);
    final dirty = _dirty(state);

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('角色与语气预设', style: TextStyle(fontSize: 17)),
          actions: [
            if (state.syncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            TextButton(
              onPressed: dirty ? () => _save(presets) : null,
              child: const Text('保存'),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(presets),
          icon: const Icon(Icons.add),
          label: const Text('新增预设'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
          children: [
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '与服务端同步失败，当前展示本地副本：${state.error}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.errorVivid),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '角色决定模型站在什么位置看你的记录，语气决定它怎么说话；'
                '两者会随每次请求下发给后端，不需要重新训练或配置模型。',
                style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
              ),
            ),
            for (var i = 0; i < presets.length; i++)
              _PresetTile(
                preset: presets[i],
                onEdit: () => _edit(i, presets),
                onDelete: () => setState(() {
                  _draft = [...presets]..removeAt(i);
                }),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewPreset preset;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onEdit,
        title: Text(
          preset.name.isEmpty ? '（未命名）' : preset.name,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (preset.role.isNotEmpty) preset.role,
              if (preset.tone.isNotEmpty) '语气：${preset.tone}',
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.5),
          ),
        ),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: '删除',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
      ),
    );
  }
}

/// 单条预设的编辑面板（键盘弹出时自动上移）。
class _PresetEditor extends StatefulWidget {
  const _PresetEditor({required this.preset});

  final ReviewPreset preset;

  @override
  State<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends State<_PresetEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.preset.name);
  late final TextEditingController _role =
      TextEditingController(text: widget.preset.role);
  late final TextEditingController _tone =
      TextEditingController(text: widget.preset.tone);

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _tone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('编辑预设', style: TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '名称',
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _role,
              maxLines: 5,
              minLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '角色设定',
                hintText: '例如：你是陪伴我多年的朋友，熟悉我的生活节奏。',
                alignLabelWithHint: true,
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tone,
              maxLines: 4,
              minLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: '语气要求',
                hintText: '例如：温和、具体、不评判；先讲事实再给一句观察。',
                alignLabelWithHint: true,
                isDense: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final draft = widget.preset.copyWith(
                      name: _name.text.trim(),
                      role: _role.text.trim(),
                      tone: _tone.text.trim(),
                    );
                    final problem = draft.problem;
                    if (problem != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(problem),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(draft);
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
