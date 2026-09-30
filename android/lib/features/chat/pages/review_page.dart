import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/chat/models/review_models.dart';
import 'package:torrid/features/chat/providers/review_providers.dart';

/// 近期回顾：后端从 booklet/essay 数据算确定性统计（+ 可选随机素材），
/// 交本地模型按选定角色与语气写成叙述。
///
/// 生成结果只存本机（右侧抽屉里可回看与删除），预设以服务端为权威。
class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key});

  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _focusController = TextEditingController();

  /// 选中的预设 ID；为空或已失效时回落到列表第一个。
  String? _presetId;

  ReviewScope _scope = const ReviewScope();

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  ReviewPreset? _selectedPreset(ReviewPresetsState state) {
    if (state.presets.isEmpty) return null;
    for (final preset in state.presets) {
      if (preset.id == _presetId) return preset;
    }
    return state.presets.first;
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final current = _scope.resolve(now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime.parse(current.from),
        end: DateTime.parse(current.to),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _scope = ReviewScope(
        kind: ReviewRangeKind.custom,
        from: picked.start,
        to: picked.end,
      );
    });
  }

  void _selectRange(ReviewRangeKind kind) {
    if (kind == ReviewRangeKind.custom) {
      _pickCustomRange();
      return;
    }
    setState(() => _scope = ReviewScope(kind: kind));
  }

  Future<void> _generate(ReviewPreset preset) {
    return ref.read(reviewDraftControllerProvider.notifier).generate(
          preset: preset,
          scope: _scope,
          focus: _focusController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final presets = ref.watch(reviewPresetsControllerProvider);
    final history = ref.watch(reviewHistoryControllerProvider);
    final draft = ref.watch(reviewDraftControllerProvider);
    final draftController = ref.read(reviewDraftControllerProvider.notifier);
    final preset = _selectedPreset(presets);

    ref.listen(reviewDraftControllerProvider.select((value) => value.notice),
        (previous, next) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), duration: const Duration(seconds: 3)),
      );
      draftController.clearNotice();
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('近期回顾', style: TextStyle(fontSize: 17)),
        actions: [
          IconButton(
            tooltip: '历史回顾',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: '角色与语气预设',
            onPressed: () => context.pushNamed('chat_review_presets'),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      endDrawer: _HistoryDrawer(
        records: history,
        onOpen: (record) {
          draftController.show(record);
          Navigator.of(context).pop();
        },
        onDelete: (record) =>
            ref.read(reviewHistoryControllerProvider.notifier).remove(record.id),
        onClear: () => ref.read(reviewHistoryControllerProvider.notifier).clear(),
      ),
      body: Column(
        children: [
          _ScopeBar(
            presets: presets,
            selected: preset,
            scope: _scope,
            focusController: _focusController,
            onPresetChanged: (id) => setState(() => _presetId = id),
            onRangeChanged: _selectRange,
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody(draft)),
          if (draft.error != null)
            _ErrorBar(
              error: draft.error!,
              onRetry: preset == null ? null : () => _generate(preset),
            ),
          _ActionBar(
            streaming: draft.streaming,
            enabled: preset != null && _scope.isComplete,
            onGenerate: preset == null ? null : () => _generate(preset),
            onStop: draftController.stop,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ReviewDraftState draft) {
    if (draft.isEmpty) {
      return draft.streaming
          ? const _CenteredNote(
              icon: Icons.hourglass_top,
              title: '正在汇总这段时间的记录…',
              detail: '模型加载与统计需要几十秒，首句出现前请稍候。',
            )
          : const _CenteredNote(
              icon: Icons.auto_awesome,
              title: '选好角色与时间范围',
              detail: '回顾完全由本机模型根据你的打卡与随笔写成，结果只保存在这台手机上。',
            );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      children: [
        if (draft.stats.trim().isNotEmpty) _StatsCard(stats: draft.stats),
        if (draft.content.trim().isNotEmpty) _NarrativeCard(content: draft.content),
        if (draft.streaming) const _StreamingTail(),
      ],
    );
  }
}

/// 顶部：预设 + 时间范围 + 关注点。
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.presets,
    required this.selected,
    required this.scope,
    required this.focusController,
    required this.onPresetChanged,
    required this.onRangeChanged,
  });

  final ReviewPresetsState presets;
  final ReviewPreset? selected;
  final ReviewScope scope;
  final TextEditingController focusController;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<ReviewRangeKind> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: presets.presets.isEmpty
                    ? const Text(
                        '还没有预设，请先到「角色与语气预设」里添加',
                        style: TextStyle(fontSize: 13, color: AppTheme.errorVivid),
                      )
                    : InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '角色与语气',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selected?.id,
                            isExpanded: true,
                            isDense: true,
                            items: [
                              for (final preset in presets.presets)
                                DropdownMenuItem(
                                  value: preset.id,
                                  child: Text(
                                    preset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) onPresetChanged(value);
                            },
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (presets.syncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (presets.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '预设未能与服务端同步，当前用的是本地副本：${presets.error}',
                style: const TextStyle(fontSize: 11, color: AppTheme.errorVivid),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final kind in ReviewRangeKind.values)
                ChoiceChip(
                  label: Text(kind.label),
                  selected: scope.kind == kind,
                  onSelected: (_) => onRangeChanged(kind),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              scope.isComplete
                  ? '统计范围：${scope.describe(DateTime.now())}'
                  : '请选择自定义范围的起止日期',
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
            ),
          ),
          TextField(
            controller: focusController,
            maxLines: 1,
            decoration: const InputDecoration(
              labelText: '关注点（可选）',
              hintText: '例如：想聊聊这个月的作息',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// "本次依据"：服务端算出的确定性统计。
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final String stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text(
          '本次依据（后端统计）',
          style: TextStyle(fontSize: 13, color: AppTheme.primary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              stats,
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 回顾正文。
class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '回顾',
                    style: TextStyle(fontSize: 13, color: AppTheme.primary),
                  ),
                ),
                IconButton(
                  tooltip: '复制',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    // 文本不做可选中：与对话页同理，选择器会抢走上下拖动
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              ],
            ),
            Text(content, style: const TextStyle(fontSize: 14.5, height: 1.75)),
          ],
        ),
      ),
    );
  }
}

class _StreamingTail extends StatelessWidget {
  const _StreamingTail();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            '正在续写…',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 底部操作条。
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.streaming,
    required this.enabled,
    required this.onGenerate,
    required this.onStop,
  });

  final bool streaming;
  final bool enabled;
  final VoidCallback? onGenerate;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                streaming ? '生成中，可随时停止' : '结果只保存在本机，不会上传',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            if (streaming)
              FilledButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('停止'),
              )
            else
              FilledButton.icon(
                onPressed: enabled ? onGenerate : null,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('生成回顾'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.error, this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重试', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: AppTheme.primary.withAlpha(150)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右侧抽屉：本地历史回顾。
class _HistoryDrawer extends StatelessWidget {
  const _HistoryDrawer({
    required this.records,
    required this.onOpen,
    required this.onDelete,
    required this.onClear,
  });

  final List<ReviewRecord> records;
  final ValueChanged<ReviewRecord> onOpen;
  final ValueChanged<ReviewRecord> onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: const Text('历史回顾', style: TextStyle(fontSize: 15)),
              subtitle: Text(
                '共 ${records.length} 条，只存在本机',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: records.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      onPressed: () => _confirmClear(context),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有生成过回顾',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return ListTile(
                          dense: true,
                          onTap: () => onOpen(record),
                          title: Text(
                            record.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${record.span} · ${record.presetName}\n'
                            '${_timeLabel(record.createdAt)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: '删除',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDelete(record),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史回顾？'),
        content: const Text('只会删除本机保存的回顾文本，不影响打卡与随笔数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) onClear();
  }

  static String _timeLabel(DateTime at) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}
