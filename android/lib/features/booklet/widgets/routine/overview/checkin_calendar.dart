import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';

class CheckinCalendar extends StatefulWidget {
  final Style style;
  final List<Record> records;

  final String? selectedTaskId;
  const CheckinCalendar({
    super.key,
    required this.style,
    required this.records,
    this.selectedTaskId,
  });

  @override
  State<CheckinCalendar> createState() => _CheckinCalendarState();
}

class _CheckinCalendarState extends State<CheckinCalendar> {
  DateTime? _selectedMonth;

  int _statusIndex(Record? record, Style style) {
    if (record == null) return 0;
    final taskId = widget.selectedTaskId;
    if (taskId != null) return record.taskCompletion[taskId] == true ? 1 : 5;
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
    final style = widget.style;
    final records = widget.records;
    final start =
        records.isNotEmpty && records.last.date.isBefore(style.startDate)
        ? records.last.date
        : style.startDate;
    final end = records.isEmpty ? style.startDate : records.first.date;
    final firstMonth = DateTime(start.year, start.month);
    final lastMonth = DateTime(end.year, end.month);
    final selected = _selectedMonth;
    final month =
        selected != null &&
            !selected.isBefore(firstMonth) &&
            !selected.isAfter(lastMonth)
        ? selected
        : lastMonth;
    final offset = month.weekday - 1;
    final endDay = DateTime(month.year, month.month + 1, 0).day;
    final recordsByDay = {
      for (final record in records)
        if (record.date.year == month.year && record.date.month == month.month)
          record.date.day: record,
    };
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上个月',
              onPressed: month.isAfter(firstMonth)
                  ? () => setState(
                      () => _selectedMonth = DateTime(
                        month.year,
                        month.month - 1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                monthFormatter.format(month),
                style: noteTitle,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              tooltip: '下个月',
              onPressed: month.isBefore(lastMonth)
                  ? () => setState(
                      () => _selectedMonth = DateTime(
                        month.year,
                        month.month + 1,
                      ),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final day in const ['一', '二', '三', '四', '五', '六', '日'])
              Expanded(
                child: Text(day, style: noteSmall, textAlign: TextAlign.center),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: offset + endDay,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final day = index - offset + 1;
            final record = recordsByDay[day];
            final mood = record?.mood;
            return InkWell(
              onTap: record == null
                  ? null
                  : () => _openDateDetailDialog(
                      context,
                      DateTime(month.year, month.month, day),
                      record,
                      style,
                    ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: checkInColors[_statusIndex(record, style)],
                  border: Border.all(
                    color: const Color(0xFFD4C8B8),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text('$day', style: noteSmall),
                    if (record?.message.isNotEmpty == true)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: messageMarkerColor,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(dimension: 6),
                        ),
                      ),
                    if (mood != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
