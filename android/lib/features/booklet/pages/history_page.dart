import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';
import 'package:torrid/features/booklet/models/history_entry.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';
import 'package:torrid/features/booklet/providers/history_provider.dart';

class BookletHistoryPage extends ConsumerStatefulWidget {
  final String? styleId;
  const BookletHistoryPage({super.key, this.styleId});

  @override
  ConsumerState<BookletHistoryPage> createState() => _BookletHistoryPageState();
}

class _BookletHistoryPageState extends ConsumerState<BookletHistoryPage> {
  late String? _styleId = widget.styleId;

  @override
  Widget build(BuildContext context) {
    final styleStream = ref.watch(styleStreamProvider);
    final styles = List.of(
      styleStream.asData?.value ?? ref.read(styleBoxProvider).values,
    )..sort((a, b) => b.startDate.compareTo(a.startDate));
    final selected = styles.any((style) => style.id == _styleId)
        ? _styleId
        : null;
    final entries = ref.watch(bookletHistoryProvider(styleId: selected));
    final styleColors = {
      for (final (index, style) in styles.indexed)
        style.id: Colors.primaries[index % Colors.primaries.length].shade600,
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E1),
      appBar: AppBar(title: const Text('历史回看')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey(selected),
              initialValue: selected ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '打卡计划',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部计划')),
                for (final style in styles)
                  DropdownMenuItem(
                    value: style.id,
                    child: Text(
                      '${DateFormat('yyyy.MM.dd').format(style.startDate)} · ${style.tasks.map((task) => task.title).take(2).join(' / ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _styleId = value == '' ? null : value),
            ),
          ),
          Expanded(
            child: entries.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('读取历史失败：$error')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('还没有留言', textAlign: TextAlign.center),
                    ),
                  );
                }
                return ListView.builder(
                  key: ValueKey(selected),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final date = entry.record.date;
                    final showMonth =
                        index == 0 ||
                        entries[index - 1].record.date.year != date.year ||
                        entries[index - 1].record.date.month != date.month;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMonth)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              DateFormat('yyyy年MM月').format(date),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        _HistoryCard(
                          key: ValueKey(entry.record.id),
                          entry: entry,
                          timelineColor:
                              styleColors[entry.record.styleId] ??
                              Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final BookletHistoryEntry entry;
  final Color timelineColor;
  const _HistoryCard({
    super.key,
    required this.entry,
    required this.timelineColor,
  });

  @override
  Widget build(BuildContext context) {
    final record = entry.record;
    final style = entry.style;
    final colors = Theme.of(context).colorScheme;
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: timelineColor.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${DateFormat('MM月dd日').format(record.date)} ${weekdays[record.date.weekday - 1]}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (record.mood != null)
                        MoodDisplay(
                          mood: record.mood,
                          iconSize: 16,
                          showLabel: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    record.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  ExpansionTile(
                    key: PageStorageKey(record.id),
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    minTileHeight: 32,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      style == null
                          ? '已保存 ${entry.completedCount} 项完成记录'
                          : '完成 ${entry.completedCount} / ${entry.taskCount} 项',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    children: [
                      if (style == null) const Text('保留了留言与完成状态，无法还原原任务名称。'),
                      if (style != null)
                        for (final task in style.tasks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(
                                  record.taskCompletion[task.id] == true
                                      ? Icons.check_circle_outline
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: record.taskCompletion[task.id] == true
                                      ? colors.primary
                                      : colors.outline,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(task.title)),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 1,
          top: 12,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: timelineColor,
            ),
          ),
        ),
      ],
    );
  }
}
