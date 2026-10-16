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
import 'package:torrid/features/booklet/models/task.dart';

/// 历来打卡信息总览页面
/// 展示当前样式的打卡统计、日历视图，支持切换样式和创建新样式
class BookletOverviewPage extends ConsumerStatefulWidget {
  const BookletOverviewPage({super.key});

  @override
  ConsumerState<BookletOverviewPage> createState() =>
      _BookletOverviewPageState();
}

class _BookletOverviewPageState extends ConsumerState<BookletOverviewPage> {
  Style? _currentStyle; // 当前选中的打卡样式
  List<Record> _relatedRecords = []; // 当前样式的所有打卡记录（按日期倒序）
  String? _selectedTaskId; // 当前选中的任务ID（用于筛选日历展示）

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final latestStyle = ref.read(latestStyleProvider);
      if (latestStyle != null) {
        _currentStyle = latestStyle;
      }
      setState(() {});
    });
  }

  /// 切换选中的样式（下拉框回调）
  /// [newStyle]：新选中的样式
  void _onStyleChanged(String? newStyleId) {
    if (newStyleId == null || newStyleId == _currentStyle?.id) return;
    setState(() {
      _currentStyle = ref.read(styleByIdProvider(newStyleId));
      _selectedTaskId = null; // 切换样式时重置任务筛选
    });
  }

  /// 当前筛选任务的标题；任务已被删除时回退到默认标题
  String _selectedTaskTitle() {
    final tasks = _currentStyle?.tasks ?? const <Task>[];
    for (final task in tasks) {
      if (task.id == _selectedTaskId) return task.title;
    }
    return '所选任务';
  }

  Future<void> _openCreateStyleBottomSheet() async {
    final style = await showModalBottomSheet<Style>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5F0E1),
      builder: (_) => const CreateStyleSheet(),
    );
    if (!mounted || style == null) return;
    setState(() {
      _currentStyle = style;
      _selectedTaskId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 响应式数据
    Map<String, int> taskCompletionCounts = {};
    if (_currentStyle != null) {
      _relatedRecords = ref.watch(recordsByStyleIdProvider(_currentStyle!.id));
      // 获取所有任务的完成次数
      taskCompletionCounts = ref.watch(
        allTaskCompletionCountsProvider(_currentStyle!.id),
      );
    }

    // UI
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
              // 页面标题
              Text('历来打卡总览', style: noteTitle.copyWith(fontSize: 22)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          BookletHistoryPage(styleId: _currentStyle?.id),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('留言时间轴'),
                ),
              ),
              const SizedBox(height: 20),

              // 顶部操作栏（样式选择 + 新建按钮）
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: StyleDropdown(
                      currentStyle: _currentStyle,
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

              // 打卡计划概览卡片
              CompactStyleOverview(currentStyle: _currentStyle),
              const SizedBox(height: 6),

              // 打卡样式的任务展示（点击可筛选日历）
              if (_currentStyle != null) ...[
                Row(
                  children: [
                    Expanded(child: Text('打卡任务', style: noteTitle)),
                    if (_selectedTaskId != null)
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
                    itemCount: _currentStyle!.tasks.length,
                    itemBuilder: (context, index) {
                      Task task = _currentStyle!.tasks[index];
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

              // 打卡记录日历
              Text(
                _selectedTaskId != null
                    ? '「${_selectedTaskTitle()}」完成记录'
                    : '打卡记录总览',
                style: noteTitle,
              ),
              const SizedBox(height: 12),
              CheckinCalendar(
                style: _currentStyle,
                records: _relatedRecords,
                selectedTaskId: _selectedTaskId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
