import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/pages/routine_overview.dart';

import 'package:torrid/features/booklet/providers/routine_notifier_provider.dart';
import 'package:torrid/features/booklet/providers/status_provider.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/topbar.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_detail_sheet.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/models/record.dart';


// TODO: 引入riverpod重构本模块, 拆分组件!  (近800行的routine_overview.dart怪吓人的).
class RoutinePage extends ConsumerStatefulWidget {
  const RoutinePage({super.key});

  @override
  ConsumerState<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends ConsumerState<RoutinePage> {
  Style? _latestStyle;
  late Record _todayRecord;
  // 用以呈现渲染的数据
  List<Task> _tasks = [];
  Map<String, dynamic> _stats = {};
  final List<bool> _completions = [];
  // 控制消息输入框的控制器
  late TextEditingController _messageController;
  late FocusNode _focusNode;
  // routine的数据操作Notifier
  RoutineService? _server;

  // # record变动(任务完成情况, 标题/描述, 留言)
  Future<void> toggleCompletion(String taskId, bool completed) async {
    _todayRecord.taskCompletion[taskId] = completed;
    await _server!.putRecord(styleId: _latestStyle!.id, record: _todayRecord);
  }

  // # 保存消息到记录
  Future<void> saveMessage() async {
    if (_latestStyle == null) return;
    _todayRecord.message = _messageController.text;
    await _server!.putRecord(styleId: _latestStyle!.id, record: _todayRecord);
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
      _todayRecord =
          ref.watch(todayRecordProvider) ??
          Record.empty(style: _latestStyle!);
      _completions.clear();

      _tasks = _latestStyle!.tasks;
      _stats = _latestStyle!.toJson();
      _stats['latest_streak'] = ref.watch(
        currentStreakProvider(_latestStyle!.id),
      );

      for (final task in _latestStyle!.tasks) {
        _completions.add(_todayRecord.taskCompletion[task.id] ?? false);
      }
      _messageController.text = _todayRecord.message;
    }

    // UI
    return Container(
      color: Colors.yellow.shade50,
      child: Column(
        children: [
          // 统计信息卡片, 点击可以查看总览
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => RoutineOverviewPage()),
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
