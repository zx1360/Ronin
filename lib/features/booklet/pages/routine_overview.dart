import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:torrid/features/booklet/widgets/routine/new_task.dart';
import 'package:torrid/features/booklet/widgets/routine/newtask_inputitem.dart';
import 'package:torrid/features/booklet/widgets/routine/global_variable.dart';
import 'package:torrid/features/booklet/widgets/routine/overview_widgets.dart';

// 工具类
import 'package:torrid/shared/utils/util.dart';
// 导入数据模型与Hive服务
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/services__to-core/booklet/booklet_hive_service.dart';

/// 历来打卡信息总览页面
/// 展示当前样式的打卡统计、日历视图，支持切换样式和创建新样式
class RoutineOverviewPage extends StatefulWidget {
  const RoutineOverviewPage({super.key});

  @override
  State<RoutineOverviewPage> createState() => _RoutineOverviewPageState();
}

class _RoutineOverviewPageState extends State<RoutineOverviewPage> {
  Style? _currentStyle; // 当前选中的打卡样式
  List<Record> _relatedRecords = []; // 当前样式的所有打卡记录（按日期倒序）
  final ImagePicker _imagePicker = ImagePicker(); // 图片选择器
  final List<TextEditingController> _titleControllers = []; // 新建样式时的任务标题控制器

  @override
  void initState() {
    super.initState();
    _loadInitialData(); // 初始化加载数据
  }

  /// 加载初始数据（最新样式 + 对应打卡记录）
  void _loadInitialData() {
    final latestStyle = BookletHiveService.getLatestStyle();
    if (latestStyle != null) {
      _currentStyle = latestStyle;
      _relatedRecords = BookletHiveService.getRecordsByStyleId(latestStyle.id);
    }
  }

  /// 切换选中的样式（下拉框回调）
  /// [newStyle]：新选中的样式
  void _onStyleChanged(String? newStyleId) {
    if (newStyleId != _currentStyle?.id) {
      setState(() {
        _currentStyle = BookletHiveService.getStyleById(newStyleId!);
        _relatedRecords = BookletHiveService.getRecordsByStyleId(newStyleId);
      });
    }
  }

  /// 检查今天是否有任何打卡记录
  bool _hasTodayRecord() {
    final today = getTodayDate();
    return BookletHiveService.getAllRecords().any(
      (r) => Util.isSameDay(r.date, today),
    );
  }

  /// 删除今天所有打卡记录（创建新样式前确认用）
  Future<void> _deleteTodayRecords() async {
    final today = getTodayDate();
    final todayRecords = BookletHiveService.getAllRecords()
        .where((r) => Util.isSameDay(r.date, today))
        .toList();
    for (final record in todayRecords) {
      await Hive.box<Record>(
        BookletHiveService.recordBoxName,
      ).delete(record.id);
    }
    await BookletHiveService.refreshOne(_currentStyle!.id);
  }

  /// 打开新建样式BottomSheet（最大高度85%设备高度，超出可滚动）
  void _openCreateStyleBottomSheet() async {
    // 检查今天是否有记录，有则弹窗确认
    if (_hasTodayRecord()) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFFF5F0E1),
          title: Text('提示', style: noteTitle),
          content: Text('今天已有打卡记录，继续创建新样式将删除今天所有记录，是否继续？', style: noteText),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '取消',
                style: noteText.copyWith(color: const Color(0xFF8B7355)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '继续',
                style: noteText.copyWith(color: const Color(0xFFD32F2F)),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      await _deleteTodayRecords(); // 确认后删除今天记录
    }
    // 如果前一个样式是今天创建的, 一同删去.
    await BookletHiveService.deleteTodayStyle();

    // 初始化新样式的任务相关控制器
    _titleControllers.clear();
    final List<TextEditingController> descControllers = [];
    final List<String> imagePaths = [];
    final List<XFile?> imageFiles = [];
    final ValueNotifier<List<NewTask>> taskList = ValueNotifier([]);

    // 更新任务列表UI
    void updateTasks() {
      taskList.value = _titleControllers.asMap().entries.map((entry) {
        final index = entry.key;
        return NewTask(
          index: index,
          titleCtrl: entry.value,
          descCtrl: descControllers[index],
          imagePath: imagePaths[index],
        );
      }).toList();
    }

    /// 选择任务图片（从相册）
    /// [index]：任务序号
    Future<void> selectTaskImage(int index) async {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 图片质量压缩
      );
      if (pickedFile != null && mounted) {
        imagePaths[index] = pickedFile.path;
        imageFiles[index] = pickedFile;
      }
      updateTasks();
    }

    /// 删除任务组件（至少保留1个任务）
    /// [index]：任务序号
    void deleteTaskWidget(int index) {
      if (_titleControllers.length <= 1) return;
      _titleControllers.removeAt(index);
      descControllers.removeAt(index);
      imagePaths.removeAt(index);
      imageFiles.removeAt(index);
      updateTasks();
    }

    /// 添加任务组件（最多5个任务）
    void addTaskWidget() {
      if (_titleControllers.length >= maxTaskCount) return;
      final titleCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      _titleControllers.add(titleCtrl);
      descControllers.add(descCtrl);
      imagePaths.add('');
      imageFiles.add(null);

      // 更新任务列表UI
      updateTasks();
    }

    // 保存图片到 '外部私有空间'
    Future<void> saveImages() async {
      for (int i = 0; i < imagePaths.length; i++) {
        if (imagePaths[i] == '' || imageFiles[i] == null) continue;
        try {
          // 获取应用外部私有存储目录（Android的getExternalFilesDir，iOS的Documents）
          final directory = await getExternalStorageDirectory();
          if (directory == null) return;

          // 确保目录存在
          await directory.create(recursive: true);

          // 生成唯一文件名（使用时间戳+原文件扩展名）
          final originalFileName = path.basename(imagePaths[i]);
          final fileExtension = path.extension(originalFileName);
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final newFileName = 'task_$timestamp$fileExtension';

          // 目标保存路径
          final targetPath = path.join(
            directory.path,
            "img_storage/booklet",
            newFileName,
          );

          File(targetPath).writeAsBytes(await imageFiles[i]!.readAsBytes());
          imagePaths[i] = path.join("img_storage/booklet", newFileName);
        } catch (e) {
          print('保存图片失败: $e');
          return;
        }
      }
    }

    /// 提交新样式（验证输入 + 保存到Hive）
    Future<void> submitNewStyle() async {
      // 验证任务输入（至少1个非空标题）
      final validTasks = _titleControllers.asMap().entries.where((entry) {
        final title = entry.value.text.trim();
        return title.isNotEmpty;
      }).toList();
      if (validTasks.isEmpty) {
        if (!mounted) return;
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '至少需要1个非空任务',
              style: TextStyle(color: const Color.fromARGB(255, 219, 185, 84)),
            ),
            backgroundColor: const Color.fromARGB(255, 141, 118, 49),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // 保存图片 (将imagePaths替换为复制之后的新路径了!)
      await saveImages();

      // 构建任务列表
      final tasks = validTasks.map((entry) {
        final index = entry.key;
        return Task.noId(
          title: entry.value.text.trim(),
          description: descControllers[index].text.trim(),
          image: imagePaths[index],
        );
      }).toList();

      // 创建新Style
      final newStyle = Style.noId(
        startDate: getTodayDate(),
        validCheckIn: 0,
        fullyDone: 0,
        longestStreak: 0,
        longestFullyStreak: 0,
        tasks: tasks,
      );

      // 保存到Hive并刷新统计
      await Hive.box<Style>(
        BookletHiveService.styleBoxName,
      ).put(newStyle.id, newStyle);
      await BookletHiveService.refreshOne(newStyle.id);

      // 关闭BottomSheet并刷新页面数据
      if (mounted) {
        context.pop();
        // 重新加载最新样式和记录
        _loadInitialData();
        setState(() {});
      }
    }

    addTaskWidget(); // 初始化第一个任务

    // 显示BottomSheet（最大高度85%设备高度）
    if (mounted) {
      await showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFFF5F0E1),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        isScrollControlled: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16, // 适配键盘
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.85, // 最大高度85%设备高度
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text('创建新打卡样式', style: noteTitle),
                  const SizedBox(height: 16),

                  // 任务列表
                  ValueListenableBuilder(
                    valueListenable: taskList,
                    builder: (context, taskList, child) => Column(
                      children: taskList
                          .map(
                            (task) => inputItem(
                              task: task,
                              onDelete: () => deleteTaskWidget(task.index),
                              onSelectImage: () => selectTaskImage(task.index),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 添加任务按钮
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _titleControllers.length >= maxTaskCount
                          ? null
                          : addTaskWidget,
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('添加任务（最多$maxTaskCount个）', style: noteSmall),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F0E1),
                        foregroundColor: const Color(0xFF8B5A2B),
                        side: const BorderSide(color: Color(0xFFD4C8B8)),
                        disabledBackgroundColor: const Color(0xFFE8E2D3),
                        disabledForegroundColor: const Color(0xFF8B7355),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 提交按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitNewStyle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5A2B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('确认创建', style: noteText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  /// 获取打卡日历的日期范围（当前样式的第一条记录 ~ 最后一条记录）
  DateTimeRange _getCalendarDateRange() {
    if (_relatedRecords.isEmpty) {
      return DateTimeRange(start: getTodayDate(), end: getTodayDate());
    }
    // 相关记录已按日期倒序，最早日期=最后一条记录，最晚日期=第一条记录
    final earliestDate = DateTime(
      _relatedRecords.last.date.year,
      _relatedRecords.last.date.month,
      _relatedRecords.last.date.day,
    );
    final latestDate = DateTime(
      _relatedRecords.first.date.year,
      _relatedRecords.first.date.month,
      _relatedRecords.first.date.day,
    );
    return DateTimeRange(start: earliestDate, end: latestDate);
  }

  /// 根据日期获取打卡状态（返回颜色索引，对应checkInColors）
  /// [date]：目标日期
  int _getCheckInStatusIndex(DateTime date) {
    if (_currentStyle == null) return 0;

    final targetRecord = _relatedRecords.firstWhere(
      (r) => Util.isSameDay(r.date, date),
      orElse: () => Record.empty(styleId: _currentStyle!.id),
    );

    // 无记录或未完成任一任务
    if (targetRecord.taskCompletion.isEmpty ||
        targetRecord.taskCompletion.values.every((v) => !v)) {
      return 0;
    }

    // 计算未完成任务数
    final totalTasks = _currentStyle!.tasks.length;
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
    if (_currentStyle == null) return false;

    final targetRecord = _relatedRecords.firstWhere(
      (r) => Util.isSameDay(r.date, date),
      orElse: () => Record.empty(styleId: _currentStyle!.id),
    );
    return targetRecord.message.isNotEmpty;
  }

  /// 打开日期详情弹窗（展示该日期的打卡记录和任务完成情况）
  /// [date]：目标日期
  void _openDateDetailDialog(DateTime date) {
    if (_currentStyle == null) return;

    final targetRecord = _relatedRecords.firstWhere(
      (r) => Util.isSameDay(r.date, date),
      orElse: () => Record.empty(styleId: _currentStyle!.id),
    );
    print(targetRecord.toJson());

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
              ..._currentStyle!.tasks.map((task) {
                final isCompleted =
                    targetRecord.taskCompletion[task.id] ?? false;
                return Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isCompleted
                          ? const Color(0xFF8B5A2B)
                          : const Color(0xFF8B7355),
                      size: 16,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

  /// 构建GitHub式打卡日历（支持月份倒序、星期对齐）
  Widget _buildCheckInCalendar() {
    if (_currentStyle == null) {
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
                buildWeekDayLabel('一'),
                buildWeekDayLabel('二'),
                buildWeekDayLabel('三'),
                buildWeekDayLabel('四'),
                buildWeekDayLabel('五'),
                buildWeekDayLabel('六'),
                buildWeekDayLabel('日'),
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
                final targetRecord = _relatedRecords.firstWhere(
                  (r) => Util.isSameDay(r.date, date),
                  orElse: () => Record.empty(styleId: _currentStyle!.id),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E1),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/3.jpg'),
            fit: BoxFit.cover,
            opacity: 0.15,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 页面标题
              Text('历来打卡总览', style: noteTitle.copyWith(fontSize: 22)),
              const SizedBox(height: 20),

              // 顶部操作栏（样式选择 + 新建按钮）
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: buildStyleDropdown(_currentStyle, _onStyleChanged),
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
                    child: Text('开始新样式', style: TextStyle(
                      color: Colors.amber
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 打卡计划概览卡片
              buildCompactStyleOverview(_currentStyle),
              const SizedBox(height: 24),

              // 打卡记录日历
              Text('打卡记录总览', style: noteTitle),
              const SizedBox(height: 12),
              _buildCheckInCalendar(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
