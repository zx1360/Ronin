import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';
import 'package:torrid/shared/utils/util.dart';

class CheckinCalendar extends StatelessWidget {
  final BuildContext context;
  final Style? style;
  final List<Record> records;
  const CheckinCalendar({
    super.key,
    required this.context,
    required this.style,
    required this.records,
  });

  /// 构建星期标题（一 ~ 日）
  /// [label]：星期文本（如"一"）
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

  /// 获取打卡日历的日期范围（当前样式的第一条记录 ~ 最后一条记录）
  DateTimeRange _getCalendarDateRange() {
    if (records.isEmpty) {
      return DateTimeRange(
        start: getTodayDate(),
        end: getTodayDate(),
      );
    }
    // 相关记录已按日期倒序，最早日期=最后一条记录，最晚日期=第一条记录
    final earliestDate = DateTime(
      records.last.date.year,
      records.last.date.month,
      records.last.date.day,
    );
    final latestDate = DateTime(
      records.first.date.year,
      records.first.date.month,
      records.first.date.day,
    );
    return DateTimeRange(start: earliestDate, end: latestDate);
  }

  /// 根据日期获取打卡状态（返回颜色索引，对应checkInColors）
  /// [date]：目标日期
  int _getCheckInStatusIndex(DateTime date) {
    if (style == null) return 0;

    // final targetRecord = records.firstWhere(
    //   (r) => isSameDay(r.date, date),
    //   orElse: () => Record.empty(style: style!),
    // );
    final targetRecords = records.where((record)=>isSameDay(record.date, date));
    if(targetRecords.isEmpty){
      return 0;
    }
    final targetRecord = targetRecords.first;

    // // 无记录或未完成任一任务
    // if (targetRecord.taskCompletion.isEmpty ||
    //     targetRecord.taskCompletion.values.every((v) => !v)) {
    //   return 0;
    // }

    // 计算未完成任务数
    final totalTasks = style!.tasks.length;
    final completedCount = targetRecord.taskCompletion.values
        .where((v) => v)
        .length;
    final incompleteCount = totalTasks - completedCount;

    // 根据未完成数返回颜色索引
    return switch (incompleteCount) {
      0 => 1, // 全完成
      1 => 2, // 差1个
      2 => 3, // 差2个
      3 => 4, // 差3个
      4 => 5, // 差4个（最多5个任务）
      _ => 0,
    };
  }

  /// 检查日期是否有留言
  /// [date]：目标日期
  bool _hasMessage(DateTime date) {
    if (style == null) return false;

    final targetRecord = records.firstWhere(
      (r) => isSameDay(r.date, date),
      orElse: () => Record.empty(style: style!),
    );
    return targetRecord.message.isNotEmpty;
  }

  /// 打开日期详情弹窗（展示该日期的打卡记录和任务完成情况）
  /// [date]：目标日期
  void _openDateDetailDialog(DateTime date) {
    if (style == null) return;

    final targetRecord = records.firstWhere(
      (r) => isSameDay(r.date, date),
      orElse: () => Record.empty(style: style!),
    );

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
              // 留言展示（如有）
              if (targetRecord.message.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('打卡留言：', style: noteSmall),
                    const SizedBox(height: 4),
                    Text(
                      targetRecord.message,
                      style: noteText.copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              // 任务完成情况
              Text('任务完成情况：', style: noteSmall),
              const SizedBox(height: 8),
              ...style!.tasks.map((task) {
                final isCompleted =
                    targetRecord.taskCompletion[task.id] ?? false;
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
                              // maxLines: 1,
                              overflow: TextOverflow.visible,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),

              // 无记录提示
              if (targetRecord.taskCompletion.isEmpty)
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
    if (style == null) {
      return const Center(child: Text('请先选择或创建打卡计划'));
    }

    final dateRange = _getCalendarDateRange();
    final totalDays = dateRange.end.difference(dateRange.start).inDays + 1;
    final dates = List.generate(
      totalDays,
      (i) => dateRange.start.add(Duration(days: i)),
    );

    // 按月份分组（key: 月份文本，value: 该月所有日期）
    final Map<String, List<DateTime>> monthGroups = {};
    for (final date in dates) {
      final monthKey = monthFormatter.format(date);
      if (!monthGroups.containsKey(monthKey)) {
        monthGroups[monthKey] = [];
      }
      monthGroups[monthKey]!.add(date);
    }

    // 月份倒序展示
    return Column(
      children: monthGroups.entries.toList().reversed.map((monthEntry) {
        final month = monthEntry.key;
        final monthDates = monthEntry.value;
        // 计算该月第一天的星期偏移（周一→0，周二→1，...，周日→6）
        final firstDay = monthDates.first;
        final offset = firstDay.weekday - 1; // DateTime.weekday: 1=周一，7=周日

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 月份标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(month, style: noteTitle),
            ),

            // 星期标题（一 ~ 日）
            Row(
              children: [
                _buildWeekDayLabel('一'),
                _buildWeekDayLabel('二'),
                _buildWeekDayLabel('三'),
                _buildWeekDayLabel('四'),
                _buildWeekDayLabel('五'),
                _buildWeekDayLabel('六'),
                _buildWeekDayLabel('日'),
              ],
            ),

            // 日期网格（补空格子实现星期对齐）
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, // 7列（对应星期）
                childAspectRatio: 1.2, // 方格宽高比
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: offset + monthDates.length, // 总格子数=偏移数+当月天数
              itemBuilder: (context, index) {
                // 偏移范围内的格子为空（用于对齐星期）
                if (index < offset) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.transparent,
                    ),
                  );
                }

                // 计算当前日期（偏移后）
                final date = monthDates[index - offset];
                final statusIndex = _getCheckInStatusIndex(date);
                final hasMessage = _hasMessage(date);
                // 获取目标记录（判断是否有打卡数据）
                final targetRecord = records.firstWhere(
                  (r) => isSameDay(r.date, date),
                  orElse: () => Record.empty(style: style!),
                );

                return GestureDetector(
                  // 无记录且无留言时，不触发弹窗
                  onTap: (statusIndex == 0 && targetRecord.message == "")
                      ? null
                      : () => _openDateDetailDialog(date),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 日期方格
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

                      // 留言标记（右上角小圆点）
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
