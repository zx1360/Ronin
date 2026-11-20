import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/features/booklet/pages/booklet_overview.dart';
import 'package:torrid/features/booklet/pages/history_page.dart';

import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/topbar.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_detail_sheet.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';
import 'package:torrid/core/utils/util.dart';

class BookletPage extends ConsumerStatefulWidget {
  const BookletPage({super.key});

  @override
  ConsumerState<BookletPage> createState() => _BookletPageState();
}

class _BookletPageState extends ConsumerState<BookletPage> {
  final _messageController = TextEditingController();
  final _draftRecords = <(String, DateTime), Record>{};
  (String, DateTime)? _messageScope;
  String _savedMessage = '';
  bool _saving = false;
  DateTime? _selectedDate;

  Record _recordFor(Style style, DateTime date) {
    return ref.watch(recordByDateProvider(targetDate: date)) ??
        _draftRecords.putIfAbsent((
          style.id,
          date,
        ), () => Record.empty(style: style, date: date));
  }

  void _loadMessage(Record? record) {
    final scope = record == null ? null : (record.styleId, record.date);
    final message = record?.message ?? '';
    if (scope != _messageScope || _messageController.text == _savedMessage) {
      if (_messageController.text != message) _messageController.text = message;
    }
    _messageScope = scope;
    _savedMessage = message;
  }

  Future<bool> _confirmLeavingMessage() async =>
      _messageController.text == _savedMessage ||
      await showConfirmDialog(
            context: context,
            title: '放弃未保存的留言？',
            content: '当前留言还没有保存。',
            confirmFunc: () {},
          ) ==
          true;

  Future<void> _selectDate(DateTimeRange range, DateTime current) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: range.start,
      lastDate: range.end,
      helpText: '选择打卡日期',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (selected == null || selected == current || !mounted) return;
    if (await _confirmLeavingMessage() && mounted) {
      setState(() => _selectedDate = selected);
    }
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

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(latestStyleProvider);
    final range = ref.watch(styleDateRangeProvider(style: style));
    final selected = _selectedDate;
    final date =
        range != null &&
            selected != null &&
            !selected.isBefore(range.start) &&
            !selected.isAfter(range.end)
        ? selected
        : getTodayDate();
    final record = style == null || range == null
        ? null
        : _recordFor(style, date);
    _loadMessage(record);
    final stats = style?.toJson() ?? <String, dynamic>{};
    if (style != null) {
      stats['latest_streak'] = ref.watch(currentStreakProvider(style.id));
    }

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
            tooltip: '选择打卡日期',
            onPressed: _saving || range == null
                ? null
                : () => _selectDate(range, date),
            icon: const Icon(Icons.date_range),
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
        child: ListView(
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
            if (record != null && style != null) ...[
              if (!isSameDay(date, getTodayDate()))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    MaterialLocalizations.of(context).formatFullDate(date),
                  ),
                ),
              for (final task in style.tasks)
                GestureDetector(
                  key: ValueKey(task.id),
                  onTap: () => showTaskDetails(context, task),
                  child: TaskWidget(
                    title: task.title,
                    description: task.description,
                    imgUrl: task.image,
                    completed: record.taskCompletion[task.id] ?? false,
                    switchCB: _saving
                        ? null
                        : (value) => _persist(
                            record.copyWith(
                              taskCompletion: {
                                ...record.taskCompletion,
                                task.id: value ?? false,
                              },
                            ),
                          ),
                  ),
                ),
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
                      readOnly: _saving,
                      maxLines: 3,
                      style: TextStyle(
                        color: Colors.brown[800],
                        fontSize: 14,
                        fontFamily: 'NotoSerif',
                      ),
                      decoration: InputDecoration(
                        hintText: '给这一天留段话吧…',
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
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        if (isSameDay(date, getTodayDate()))
                          MoodSelector(
                            selectedMood: record.mood,
                            onMoodChanged: _saving
                                ? null
                                : (mood) => _persist(
                                    record.copyWith(
                                      mood: mood,
                                      clearMood: mood == null,
                                    ),
                                  ),
                            compact: true,
                            iconSize: 24,
                          )
                        else
                          MoodDisplay(
                            mood: record.mood,
                            iconSize: 24,
                            showLabel: true,
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
