import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/widgets/routine/topbar/topbar.dart';
import 'package:torrid/features/booklet/widgets/routine/widget/task_widget.dart';

import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/pages/booklet_overview_page.dart';

import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/shared/widgets/file_img_builder.dart';

// TODO: 引入riverpod重构本模块, 拆分组件!  (仅800行的routine_overview.dart怪吓人的).
class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  Style? _latestStyle;
  late Record _todayRecord;
  // 用以呈现渲染的数据
  List<Task> _tasks = [];
  Map<String, dynamic> _stats = {};
  final List<bool> _completions = [];
  String _message = "";
  // 控制消息输入框的控制器
  late TextEditingController _messageController;
  late FocusNode _focusNode;

  // # record变动(任务完成情况, 标题/描述, 留言)
  Future<void> updateRecord(String taskId, bool completed) async {
    _todayRecord.taskCompletion[taskId] = completed;
    BookletHiveService.updateRecord(
      styleId: _latestStyle!.id,
      record: _todayRecord,
    );
    readFromHive();
  }

  // # 保存消息到记录
  Future<void> saveMessage() async {
    if (_latestStyle == null) return;

    setState(() {
      _message = _messageController.text;
      _todayRecord.message = _message;
    });

    await BookletHiveService.updateRecord(
      styleId: _latestStyle!.id,
      record: _todayRecord,
    );
  }

  // # 从Hive读取数据
  void readFromHive() {
    // 读取最近的样式, 如有, 设置一些信息.
    _latestStyle = BookletHiveService.getLatestStyle();
    if (_latestStyle == null) return;
    // 读取该样式下, 今天是否有记录.
    _todayRecord =
        BookletHiveService.getTodayRecordByStyleId(_latestStyle!.id) ??
        Record.empty(styleId: _latestStyle!.id);
    _completions.clear();

    setState(() {
      _tasks = _latestStyle!.tasks;
      _stats = _latestStyle!.toJson();
      _stats['latest_streak'] = BookletHiveService.getLatestStreak(
        _latestStyle!.id,
      );

      for (Task task in _latestStyle!.tasks) {
        _completions.add(_todayRecord.taskCompletion[task.id] ?? false);
      }
      _message = _todayRecord.message;
      // 更新文本控制器的值
      _messageController.text = _message;
    });
  }

  // 初始化, (读取数据)
  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _focusNode = FocusNode();
    readFromHive();
  }

  // 释放资源
  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 双击任务查看任务详情
  void _showTaskDetails(Task task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (context) {
        // 定义本弹出页的最大高度和最小宽度.
        final maxHeight = MediaQuery.of(context).size.height * 0.85;
        final minWidth = MediaQuery.of(context).size.width;
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(maxHeight: maxHeight, minWidth: minWidth),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.image.isNotEmpty)
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxHeight * 0.7,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FileImageBuilder(relativeImagePath: task.image),
                            ),
                          );
                        },
                  ),
                const SizedBox(height: 16),
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  task.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.brown[700]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.yellow.shade50,
      child: Column(
        children: [
          // 统计信息卡片, 点击可以查看总览
          // TODO: 不展示本style的最大记录, 而展示目前的连续记录.
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OverviewPage()),
              );
              readFromHive();
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
                  onDoubleTap: () => _showTaskDetails(taskData),
                  child: TaskWidget(
                    title: taskData.title,
                    description: taskData.description,
                    imgUrl: taskData.image,
                    completed: _completions.isNotEmpty
                        ? _completions[index]
                        : false,
                    switchCB: (value) {
                      updateRecord(_latestStyle!.tasks[index].id, value);
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
}
