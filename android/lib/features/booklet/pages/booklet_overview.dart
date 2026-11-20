import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/booklet/pages/history_page.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/new_style/create_style_sheet.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/checkin_calendar.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/style_info_widgets.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/task_simple_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';

class BookletOverviewPage extends ConsumerStatefulWidget {
  const BookletOverviewPage({super.key});

  @override
  ConsumerState<BookletOverviewPage> createState() =>
      _BookletOverviewPageState();
}

class _BookletOverviewPageState extends ConsumerState<BookletOverviewPage> {
  String? _styleId;
  String? _selectedTaskId;

  void _onStyleChanged(String? newStyleId) {
    setState(() {
      _styleId = newStyleId;
      _selectedTaskId = null;
    });
  }

  Future<void> _openCreateStyleBottomSheet() async {
    final style = await showModalBottomSheet<Style>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F0E1),
      builder: (_) => const CreateStyleSheet(),
    );
    if (!mounted || style == null) return;
    _onStyleChanged(style.id);
  }

  @override
  Widget build(BuildContext context) {
    final styles = ref.watch(sortedStylesProvider);
    final style =
        styles.where((style) => style.id == _styleId).firstOrNull ??
        styles.firstOrNull;
    final selectedTask = style?.tasks
        .where((task) => task.id == _selectedTaskId)
        .firstOrNull;
    final records = style == null
        ? null
        : ref.watch(recordsByStyleIdProvider(style.id));
    final counts = style == null
        ? null
        : ref.watch(allTaskCompletionCountsProvider(style.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('历来打卡总览'),
        backgroundColor: const Color(0xFFF5F0E1),
      ),
      body: Container(
        color: const Color(0xFFF5F0E1),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/1.png'),
              fit: BoxFit.cover,
              opacity: 0.15,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookletHistoryPage(styleId: style?.id),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('留言时间轴'),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: StyleDropdown(
                      key: ValueKey(style?.id),
                      currentStyle: style,
                      onStyleChanged: _onStyleChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _openCreateStyleBottomSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5A2B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    child: Text('开始新样式', style: TextStyle(color: Colors.amber)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              CompactStyleOverview(currentStyle: style),
              const SizedBox(height: 6),

              if (style != null) ...[
                Row(
                  children: [
                    Expanded(child: Text('打卡任务', style: noteTitle)),
                    if (selectedTask != null)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _selectedTaskId = null;
                          });
                        },
                        icon: const Icon(Icons.clear, size: 14),
                        label: Text('清除筛选', style: noteSmall),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8B5A2B),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final task in style.tasks)
                  GestureDetector(
                    key: ValueKey(task.id),
                    onTap: () => setState(() {
                      _selectedTaskId = selectedTask == task ? null : task.id;
                    }),
                    child: TaskSimpleWidget(
                      title: task.title,
                      description: task.description,
                      imgUrl: task.image,
                      completionCount: counts![task.id] ?? 0,
                      isSelected: selectedTask == task,
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  selectedTask == null
                      ? '打卡记录总览'
                      : '「${selectedTask.title}」完成记录',
                  style: noteTitle,
                ),
                const SizedBox(height: 12),
                CheckinCalendar(
                  key: ValueKey(style.id),
                  style: style,
                  records: records!,
                  selectedTaskId: selectedTask?.id,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
