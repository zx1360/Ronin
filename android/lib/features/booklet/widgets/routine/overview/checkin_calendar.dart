import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';
import 'package:torrid/core/utils/util.dart';

class CheckinCalendar extends StatelessWidget {
  final Style? style;
  final List<Record> records;

  final String? selectedTaskId;
  const CheckinCalendar({
    super.key,
    required this.style,
    required this.records,
    this.selectedTaskId,
  });

  Widget _buildWeekDayLabel(String label) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: const Color(0xFF8B7355), fontSize: 11),
        ),
      ),
    );
  }

  int _statusIndex(Record? record, Style style) {
    if (record == null) return 0;
    if (selectedTaskId != null) {
      return record.taskCompletion[selectedTaskId] == true ? 1 : 5;
    }

    final incomplete = style.tasks
        .where((task) => record.taskCompletion[task.id] != true)
        .length;
    return (incomplete + 1).clamp(1, checkInColors.length - 1);
  }

  void _openDateDetailDialog(
    BuildContext context,
    DateTime date,
    Record record,
    Style style,
  ) {
    final mood = record.mood;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F0E1),
        title: Text(fullDateFormatter.format(date), style: noteTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mood != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text('今日心情：', style: noteSmall),
                      const SizedBox(width: 8),
                      Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        mood.description,
                        style: noteText.copyWith(color: mood.color),
                      ),
                    ],
                  ),
                ),

              if (record.message.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('打卡留言：', style: noteSmall),
                    const SizedBox(height: 4),
                    Text(
                      record.message,
                      style: noteText.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              Text('任务完成情况：', style: noteSmall),
              const SizedBox(height: 8),
              ...style.tasks.map((task) {
                final isCompleted = record.taskCompletion[task.id] ?? false;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        isCompleted
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: isCompleted
                            ? const Color(0xFF8B5A2B)
                            : const Color(0xFF8B7355),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title, style: noteText),
                          if (task.description.isNotEmpty)
                            Text(
                              task.description,
                              style: noteSmall,
                              overflow: TextOverflow.visible,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),

              if (record.taskCompletion.isEmpty)
                Text('无打卡记录', style: noteSmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '关闭',
              style: noteText.copyWith(color: const Color(0xFF8B5A2B)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = this.style;
    if (style == null) {
      return const Center(child: Text('请先选择或创建打卡计划'));
    }

    final recordsByDate = <DateTime, Record>{};
    for (final record in records) {
      recordsByDate.putIfAbsent(dateOnly(record.date), () => record);
    }
    // 调用方按日期倒序传入记录。
    final today = getTodayDate();
    final start = records.isEmpty ? today : dateOnly(records.last.date);
    final end = records.isEmpty ? today : dateOnly(records.first.date);
    final monthGroups = <String, List<DateTime>>{};
    for (
      var date = start;
      !date.isAfter(end);
      date = DateTime(date.year, date.month, date.day + 1)
    ) {
      monthGroups.putIfAbsent(monthFormatter.format(date), () => []).add(date);
    }

    return Column(
      children: monthGroups.entries.toList().reversed.map((monthEntry) {
        final month = monthEntry.key;
        final monthDates = monthEntry.value;
        final offset = monthDates.first.weekday - 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(month, style: noteTitle),
            ),

            Row(
              children: [
                for (final day in const ['一', '二', '三', '四', '五', '六', '日'])
                  _buildWeekDayLabel(day),
              ],
            ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.2,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: offset + monthDates.length,
              itemBuilder: (context, index) {
                if (index < offset) return const SizedBox.shrink();

                final date = monthDates[index - offset];
                final record = recordsByDate[dateOnly(date)];
                final statusIndex = _statusIndex(record, style);
                final hasMessage = record?.message.isNotEmpty == true;
                final mood = record?.mood;

                return GestureDetector(
                  onTap: record == null
                      ? null
                      : () =>
                            _openDateDetailDialog(context, date, record, style),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: checkInColors[statusIndex],
                          border: Border.all(
                            color: const Color(0xFFD4C8B8),
                            width: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            dayFormatter.format(date),
                            style: noteSmall.copyWith(
                              color: date.isAfter(getTodayDate())
                                  ? const Color(0xFF8B7355).withAlpha(
                                      128,
                                    ) // 未来日期半透明
                                  : const Color(0xFF3A2E2F),
                            ),
                          ),
                        ),
                      ),

                      if (hasMessage)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: messageMarkerColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (mood != null)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Text(
                            mood.emoji,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }).toList(),
    );
  }
}
