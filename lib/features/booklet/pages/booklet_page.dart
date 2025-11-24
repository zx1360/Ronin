import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/pages/booklet_overview.dart';

import 'package:torrid/features/booklet/providers/routine_notifier_provider.dart';
import 'package:torrid/features/booklet/providers/status_provider.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/topbar.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_detail_sheet.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/models/record.dart';

class BookletPage extends ConsumerStatefulWidget {
  const BookletPage({super.key});

  @override
  ConsumerState<BookletPage> createState() => _BookletPageState();
}

class _BookletPageState extends ConsumerState<BookletPage> {
  Style? _latestStyle;
  late Record _targetRecord;
  // 用以呈现渲染的数据
  List<Task> _tasks = [];
  Map<String, dynamic> _stats = {};
  final List<bool> _completions = [];
  // 控制消息输入框的控制器
  late TextEditingController _messageController;
  late FocusNode _focusNode;
  // routine的数据操作Notifier
  RoutineService? _server;
  // 往期打卡补签相关.
  DateTime targetDate = DateTime.now();

  // # record变动(任务完成情况, 标题/描述, 留言)
  Future<void> toggleCompletion(String taskId, bool completed) async {
    _targetRecord.taskCompletion[taskId] = completed;
    await _server!.putRecord(styleId: _latestStyle!.id, record: _targetRecord);
  }

  // # 保存消息到记录
  Future<void> saveMessage() async {
    if (_latestStyle == null) return;
    _targetRecord.message = _messageController.text;
    await _server!.putRecord(styleId: _latestStyle!.id, record: _targetRecord);
  }

  // # 选择要操作的打卡日期.
  Future<void> selectDate(DateTimeRange? dateRange) async {
    if (dateRange == null) return;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: targetDate,
      firstDate: dateRange.start,
      lastDate: dateRange.end,
      helpText: '选择打卡日期',
      cancelText: '取消',
      confirmText: '确认',
    );
    if(selectedDate!=null){
      setState(() {
        targetDate=selectedDate;
      });
    }
  }

  // 初始化, (读取数据)
  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    _server = ref.watch(routineServiceProvider.notifier);
    // 响应式数据获取.
    _latestStyle = ref.watch(latestStyleProvider);
    // 如果有style记录或变动, 则(重新)绑定一系列数据监听.
    if (_latestStyle != null) {
      _targetRecord = ref.watch(recordWithDateProvider(targetDate: targetDate))??Record.empty(style: _latestStyle!);
      _completions.clear();

      _tasks = _latestStyle!.tasks;
      _stats = _latestStyle!.toJson();
      _stats['latest_streak'] = ref.watch(
        currentStreakProvider(_latestStyle!.id),
      );

      for (final task in _latestStyle!.tasks) {
        _completions.add(_targetRecord.taskCompletion[task.id] ?? false);
      }
      _messageController.text = _targetRecord.message;
    }

    // 日期范围, 打卡补签等相关.
    final dateRange = ref.watch(styleDateRangeProvider(style: _latestStyle));

    // UI
    return Scaffold(
      // 顶部栏
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
            onPressed: () {
              selectDate(dateRange);
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

      // 内容
      body: Container(
        color: Colors.yellow.shade50,
        child: Column(
          children: [
            // 统计信息卡片, 点击可以查看总览
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookletOverviewPage(),
                  ),
                );
              },
              child: Topbar(stats: _stats),
            ),

            // 任务列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  Task taskData = _tasks[index];
                  return GestureDetector(
                    onDoubleTap: () => showTaskDetails(context, taskData),
                    child: TaskWidget(
                      title: taskData.title,
                      description: taskData.description,
                      imgUrl: taskData.image,
                      completed: _completions.isNotEmpty
                          ? _completions[index]
                          : false,
                      switchCB: (value) {
                        toggleCompletion(_latestStyle!.tasks[index].id, value);
                      },
                    ),
                  );
                },
              ),
            ),

            // 留言栏
            if (_latestStyle != null)
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
                    // 消息输入框
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
                    // TODO: 保存按钮左边有一片区域空着, 也许放点小表情(天气图标) 表示当天心情?
                    // 保存按钮
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: saveMessage,
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
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 释放资源
  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
