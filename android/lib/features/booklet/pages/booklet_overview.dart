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
import 'package:torrid/features/booklet/models/record.dart';

class BookletOverviewPage extends ConsumerStatefulWidget {
  const BookletOverviewPage({super.key});

  @override
  ConsumerState<BookletOverviewPage> createState() =>
      _BookletOverviewPageState();
}

class _BookletOverviewPageState extends ConsumerState<BookletOverviewPage> {
  String? _selectedStyleId;
  String? _selectedTaskId;

  void _onStyleChanged(String? newStyleId) {
    if (newStyleId == null || newStyleId == _selectedStyleId) return;
    setState(() {
      _selectedStyleId = newStyleId;
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
    final currentStyle =
        styles.where((style) => style.id == _selectedStyleId).firstOrNull ??
        styles.firstOrNull;
    final selectedTask = currentStyle?.tasks
        .where((task) => task.id == _selectedTaskId)
        .firstOrNull;
    final List<Record> relatedRecords = currentStyle == null
        ? const []
        : ref.watch(recordsByStyleIdProvider(currentStyle.id));
    final taskCompletionCounts = currentStyle == null
        ? const <String, int>{}
        : ref.watch(allTaskCompletionCountsProvider(currentStyle.id));

    return Scaffold(
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
              Text('历来打卡总览', style: noteTitle.copyWith(fontSize: 22)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BookletHistoryPage(styleId: currentStyle?.id),
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
                      key: ValueKey(currentStyle?.id),
                      currentStyle: currentStyle,
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

              CompactStyleOverview(currentStyle: currentStyle),
              const SizedBox(height: 6),

              if (currentStyle != null) ...[
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
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  height: 200,
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 0),
                    itemCount: currentStyle.tasks.length,
                    itemBuilder: (context, index) {
                      final task = currentStyle.tasks[index];
                      final completionCount =
                          taskCompletionCounts[task.id] ?? 0;
                      final isSelected = _selectedTaskId == task.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedTaskId == task.id) {
                              _selectedTaskId = null; // 再次点击取消选中
                            } else {
                              _selectedTaskId = task.id;
                            }
                          });
                        },
                        child: TaskSimpleWidget(
                          title: task.title,
                          description: task.description,
                          imgUrl: task.image,
                          completionCount: completionCount,
                          isSelected: isSelected,
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 18),

              Text(
                selectedTask != null ? '「${selectedTask.title}」完成记录' : '打卡记录总览',
                style: noteTitle,
              ),
              const SizedBox(height: 12),
              CheckinCalendar(
                style: currentStyle,
                records: relatedRecords,
                selectedTaskId: selectedTask?.id,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
