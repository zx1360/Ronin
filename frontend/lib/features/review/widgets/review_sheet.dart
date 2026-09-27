/// "近期回顾"面板：从对话页打开。
///
/// 展示后端算出的确定性统计（`stats.facts` 是权威数字）与本地模型写的叙述，
/// 并提供周期选择、预设选择/编辑、缓存状态与"重新生成"。
/// 模型不可用时后端仍返回统计并给出 `notice`，这里必须如实展示、绝不留白。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/api/generated/api_contract.dart';
import 'package:torrid/features/review/providers/review_providers.dart';
import 'package:torrid/features/review/widgets/review_preset_dialogs.dart';

/// 打开回顾面板。
Future<void> showReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const ReviewSheet(),
  );
}

/// 可选周期（天）：默认 30，上限 365（与后端 `review.MaxDays` 一致）。
const List<int> _dayChoices = [7, 30, 90, 180, 365];

class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key});

  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  @override
  void initState() {
    super.initState();
    // 首帧之后再动 provider：build 期间改状态会触发 Riverpod 断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(reviewControllerProvider.notifier);
      controller.loadPresets();
      final state = ref.read(reviewControllerProvider);
      // 首次打开就生成一次：后端有缓存，数据没变时很快返回
      if (state.result == null && !state.generating) {
        controller.generate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider);
    final controller = ref.read(reviewControllerProvider.notifier);
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    // 预设增删改的一次性提示
    ref.listen(reviewControllerProvider.select((value) => value.notice),
        (previous, next) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
      );
      controller.dismissNotice();
    });

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(state: state),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeriodPicker(
                    days: state.days,
                    enabled: !state.generating,
                    onSelected: controller.selectDays,
                  ),
                  const SizedBox(height: 12),
                  _PresetPicker(state: state, controller: controller),
                  const SizedBox(height: 16),
                  ..._buildContent(state, controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(ReviewState state, ReviewController controller) {
    final result = state.result;

    return [
      if (state.generating) ...[
        _GeneratingCard(days: state.days, hasPrevious: result != null),
        const SizedBox(height: 12),
      ],
      if (state.error != null) ...[
        _ErrorCard(message: state.error!, onRetry: () => controller.generate()),
        const SizedBox(height: 12),
      ],
      if (result == null && state.error == null && !state.generating)
        _EmptyCard(onGenerate: () => controller.generate()),
      if (result != null) ...[
        _NoticeBanner(notice: result.notice),
        _ResultMeta(
          result: result,
          generating: state.generating,
          onRegenerate: () => controller.generate(force: true),
        ),
        const SizedBox(height: 12),
        _NarrativeBlock(narrative: result.narrative),
        const SizedBox(height: 12),
        _FactsBlock(facts: result.stats.facts),
        const SizedBox(height: 12),
        _NumbersBlock(stats: result.stats),
      ],
    ];
  }
}

/// 顶部标题栏。
class _Header extends StatelessWidget {
  const _Header({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final range = state.result?.stats;
    final subtitle = range == null
        ? '近 ${state.days} 天'
        : '近 ${range.days} 天 · ${range.from} ~ ${range.to}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '近期回顾',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            iconSize: 20,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// 周期选择（天）。
class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({
    required this.days,
    required this.enabled,
    required this.onSelected,
  });

  final int days;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('回顾周期'),
        Wrap(
          spacing: 8,
          children: [
            for (final choice in _dayChoices)
              ChoiceChip(
                label: Text(
                  choice == 365 ? '一年' : '$choice 天',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: days == choice,
                onSelected:
                    enabled ? (_) => onSelected(choice) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// 预设选择 + 管理入口。
class _PresetPicker extends StatelessWidget {
  const _PresetPicker({required this.state, required this.controller});

  final ReviewState state;
  final ReviewController controller;

  @override
  Widget build(BuildContext context) {
    final selectedId = state.selectedPreset?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('语气与角色预设')),
            TextButton.icon(
              onPressed: () => showReviewPresetManagerDialog(context),
              icon: const Icon(Icons.tune, size: 16),
              label: const Text('管理', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        if (state.loadingPresets && !state.hasPresets)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '正在读取预设…',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          )
        else if (!state.hasPresets)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.presetError == null
                    ? '预设不可用（服务端不可达）；仍可生成回顾。'
                    : '预设读取失败：${state.presetError}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.loadPresets(force: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('重试', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in state.presets)
                ChoiceChip(
                  label: Text(
                    preset.isDefault ? '${preset.name} · 默认' : preset.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: preset.id == selectedId,
                  onSelected: state.generating
                      ? null
                      : (_) => controller.selectPreset(preset.id),
                ),
            ],
          ),
      ],
    );
  }
}

/// 生成中：明确告知耗时，且不阻塞页面（面板可随时关闭，请求继续）。
class _GeneratingCard extends StatefulWidget {
  const _GeneratingCard({required this.days, required this.hasPrevious});

  final int days;
  final bool hasPrevious;

  @override
  State<_GeneratingCard> createState() => _GeneratingCardState();
}

class _GeneratingCardState extends State<_GeneratingCard> {
  late final DateTime _since = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = DateTime.now().difference(_since).inSeconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '本地模型正在撰写近 ${widget.days} 天的回顾…',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                '$seconds 秒',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(minHeight: 4),
          ),
          const SizedBox(height: 6),
          const Text(
            '可能需要一到几分钟。可以先关掉面板去聊天，生成完再回来查看。',
            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 生成失败（统计也可能没拿到）。
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppTheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onErrorContainer,
              ),
            ),
          ),
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

/// 还没有任何结果。
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline.withAlpha(120)),
      ),
      child: Column(
        children: [
          const Text(
            '还没有生成回顾',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            '统计由后端算出，本地模型负责写成一段话。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('生成回顾'),
          ),
        ],
      ),
    );
  }
}

/// `notice`：模型不可用/生成失败时的诚实降级说明，必须显眼。
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context) {
    final text = notice?.trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C88A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF9A6B1F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$text\n以下统计仍然有效。',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A5518)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 缓存状态、模型/预设来源与"重新生成"。
class _ResultMeta extends StatelessWidget {
  const _ResultMeta({
    required this.result,
    required this.generating,
    required this.onRegenerate,
  });

  final ReviewResult result;
  final bool generating;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final detail = <String>[
      if ((result.preset ?? '').isNotEmpty) '预设：${result.preset}',
      if ((result.model ?? '').isNotEmpty) '模型：${result.model}',
      if (_formatCreatedAt(result.createdAt) != null)
        '生成于 ${_formatCreatedAt(result.createdAt)}',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.cached)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '已缓存',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSecondaryContainer,
                    ),
                  ),
                ),
              if (detail.isNotEmpty)
                Text(
                  detail.join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: generating ? null : onRegenerate,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('重新生成', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  static String? _formatCreatedAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

/// 模型写的叙述（长按复制，与对话页气泡一致）。
class _NarrativeBlock extends StatelessWidget {
  const _NarrativeBlock({required this.narrative});

  final String narrative;

  @override
  Widget build(BuildContext context) {
    final text = narrative.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onLongPress: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已复制'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline.withAlpha(120)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, height: 1.55),
        ),
      ),
    );
  }
}

/// 后端给出的事实清单：这些才是权威数字。
class _FactsBlock extends StatelessWidget {
  const _FactsBlock({required this.facts});

  final List<String> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('事实清单（后端统计）'),
        for (final fact in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    fact,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 紧凑的数字概览（与 facts 同源，便于扫一眼）。
class _NumbersBlock extends StatelessWidget {
  const _NumbersBlock({required this.stats});

  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final booklet = stats.booklet;
    final essay = stats.essay;

    final essayChips = <String>[
      '${essay.articles} 篇',
      '${essay.words} 字',
      '活跃 ${essay.activeDays} 天',
      if (essay.avgWords > 0) '均 ${essay.avgWords.toStringAsFixed(0)} 字/篇',
    ];
    final bookletChips = <String>[
      '打卡 ${booklet.checkInDays} 天',
      '连续 ${booklet.currentStreak} 天',
      '最长 ${booklet.longestStreak} 天',
      '完成率 ${(booklet.completionRate * 100).toStringAsFixed(0)}%',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (essay.articles > 0) ...[
          const _SectionTitle('随笔'),
          _chips(essayChips),
          const SizedBox(height: 8),
        ],
        if (booklet.totalRecords > 0 || booklet.checkInDays > 0) ...[
          const _SectionTitle('打卡'),
          _chips(bookletChips),
        ],
      ],
    );
  }

  Widget _chips(List<String> labels) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

/// 小节标题。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}
