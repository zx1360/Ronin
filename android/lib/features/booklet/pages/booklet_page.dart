import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/pages/booklet_overview.dart';
import 'package:torrid/features/booklet/pages/history_page.dart';

import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/topbar.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_detail_sheet.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';
import 'package:torrid/core/utils/util.dart';

class BookletPage extends ConsumerStatefulWidget {
  const BookletPage({super.key});

  @override
  ConsumerState<BookletPage> createState() => _BookletPageState();
}

class _BookletPageState extends ConsumerState<BookletPage> {
  final _draftRecords = <(String, DateTime), Record>{};
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  (String, DateTime)? _messageScope;
  String _savedMessage = '';
  bool _saving = false;
  (String, DateTime)? _selectedDay;

  Record _recordFor(Style style, DateTime date) {
    final persisted = ref.watch(recordByDateProvider(targetDate: date));
    if (persisted != null) return persisted;
    return _draftRecords.putIfAbsent((
      style.id,
      date,
    ), () => Record.empty(style: style, date: date));
  }

  void _syncMessage(Record? record) {
    final scope = record == null ? null : (record.styleId, record.date);
    final message = record?.message ?? '';
    if (scope != _messageScope || _messageController.text == _savedMessage) {
      if (_messageController.text != message) _messageController.text = message;
    }
    _messageScope = scope;
    _savedMessage = message;
  }

  Future<void> _persist(Record record) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(bookletStoreProvider)
          .putRecord(styleId: record.styleId, record: record);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _selectDate(
    DateTimeRange? dateRange,
    DateTime targetDate,
  ) async {
    final styleId = ref.read(latestStyleProvider)?.id;
    if (dateRange == null || styleId == null) return;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: targetDate.isBefore(dateRange.start)
          ? dateRange.start
          : targetDate,
      firstDate: dateRange.start,
      lastDate: dateRange.end,
      helpText: '选择打卡日期',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (!mounted || selectedDate == null) return;
    if (ref.read(latestStyleProvider)?.id == styleId) {
      setState(() => _selectedDay = (styleId, selectedDate));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(latestStyleProvider);
    final dateRange = ref.watch(styleDateRangeProvider(style: style));
    final today = getTodayDate();
    final selected = _selectedDay;
    final targetDate =
        selected != null &&
            selected.$1 == style?.id &&
            !selected.$2.isAfter(today)
        ? selected.$2
        : today;
    final record = style == null ? null : _recordFor(style, targetDate);
    _syncMessage(record);
    final stats = style?.toJson() ?? <String, dynamic>{};
    if (style != null) {
      stats['latest_streak'] = ref.watch(currentStreakProvider(style.id));
    }
    final tasks = style?.tasks ?? const <Task>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "日常打卡",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '历史回看',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookletHistoryPage()),
            ),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: () {
              _selectDate(dateRange, targetDate);
            },
            icon: Icon(Icons.date_range),
          ),
        ],

        centerTitle: true,
        backgroundColor: Colors.yellow.shade200,
        elevation: 2,
        shadowColor: Colors.yellow,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),

      body: Container(
        color: Colors.yellow.shade50,
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookletOverviewPage(),
                  ),
                );
              },
              child: Topbar(stats: stats),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final taskData = tasks[index];
                  return GestureDetector(
                    onDoubleTap: () => showTaskDetails(context, taskData),
                    child: TaskWidget(
                      title: taskData.title,
                      description: taskData.description,
                      imgUrl: taskData.image,
                      completed: record?.taskCompletion[taskData.id] ?? false,
                      switchCB: (value) {
                        if (record == null) return;
                        _persist(
                          record.copyWith(
                            taskCompletion: {
                              ...record.taskCompletion,
                              taskData.id: value ?? false,
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            if (record != null)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow[100], // 淡黄色背景，符合记事本风格
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.yellow[300]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: 3,
                      style: TextStyle(
                        color: Colors.brown[800],
                        fontSize: 14,
                        fontFamily: 'NotoSerif',
                      ),
                      decoration: InputDecoration(
                        hintText: "给今天的自己留段话吧...",
                        hintStyle: TextStyle(
                          color: Colors.brown[400],
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        filled: true,
                        fillColor: Colors.yellow[50],
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      onTapOutside: (event) {
                        _focusNode.unfocus();
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // 今日：可选择心情；往期：只读显示（如有）
                        Expanded(
                          child: isSameDay(targetDate, DateTime.now())
                              ? MoodSelector(
                                  selectedMood: record.mood,
                                  onMoodChanged: (mood) => _persist(
                                    record.copyWith(
                                      mood: mood,
                                      clearMood: mood == null,
                                    ),
                                  ),
                                  compact: true,
                                  iconSize: 24,
                                )
                              : (record.mood != null
                                    ? MoodDisplay(
                                        mood: record.mood,
                                        iconSize: 24,
                                        showLabel: true,
                                      )
                                    : const SizedBox.shrink()),
                        ),
                        ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () => _persist(
                                  record.copyWith(
                                    message: _messageController.text,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.yellow[700],
                            foregroundColor: Colors.brown[900],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text("保存"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
