import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:torrid/features/booklet/providers/routine_notifier_provider.dart';
import 'package:torrid/features/booklet/providers/state_provider.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/checkin_calendar.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/newtask_inputitem.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/style_info_widgets.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/task_simple_widget.dart';
import 'package:torrid/services/io/io_service.dart';

// 工具类
import 'package:torrid/shared/utils/util.dart';
import 'package:torrid/services/debug/logging_service.dart';
// 导入数据模型与Hive服务
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/task.dart';

/// 历来打卡信息总览页面
/// 展示当前样式的打卡统计、日历视图，支持切换样式和创建新样式
class RoutineOverviewPage extends ConsumerStatefulWidget {
  const RoutineOverviewPage({super.key});

  @override
  ConsumerState<RoutineOverviewPage> createState() =>
      _RoutineOverviewPageState();
}

class _RoutineOverviewPageState extends ConsumerState<RoutineOverviewPage> {
  Style? _currentStyle; // 当前选中的打卡样式
  List<Record> _relatedRecords = []; // 当前样式的所有打卡记录（按日期倒序）
  final ImagePicker _imagePicker = ImagePicker(); // 图片选择器
  final List<TextEditingController> _titleControllers = []; // 新建样式时的任务标题控制器

  late RoutineService _server;

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
    if (newStyleId != _currentStyle?.id) {
      setState(() {
        _currentStyle = ref.read(styleWithIdProvider(newStyleId!));
      });
    }
  }

  /// 打开新建样式BottomSheet（最大高度85%设备高度，超出可滚动）
  void _openCreateStyleBottomSheet() async {
    // 检查今天是否有记录，有则弹窗确认
    if (ref.read(todayRecordProvider) != null) {
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
      // 除了点击"确定"以外的操作都直接返回.
      if (confirm != true) return;
    }
    // 新建样式前, 删除<日期为今天>的record记录和style记录
    await _server.clearBeforeNewStyle();
    // 本方法内两个setState()
    // 前者为了确保有style记录被删时, 下拉栏断言不出错.
    // 后者为了新建之后立刻显示新style的overview.
    setState(() {
      _currentStyle = ref.read(latestStyleProvider);
    });

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
          final directory = await IoService.externalStorageDir;

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
          AppLogger().error('保存图片失败: $e');
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

      // 创建新Style并保存到Hive
      final newStyle = Style.newOne(getTodayDate(), tasks);
      _server.putStyle(style: newStyle);

      // 关闭BottomSheet并刷新页面数据
      if (mounted) {
        context.pop();
        // TODO?: 重新加载最新样式和记录
        // loadInitialData();
        // setState(() {});
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
    setState(() {
      _currentStyle = ref.read(latestStyleProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    _server = ref.watch(routineServiceProvider.notifier);
    // 响应式数据
    if (_currentStyle != null) {
      _relatedRecords = ref.watch(
        recordsWithStyleidProvider(_currentStyle!.id),
      );
    }

    // UI
    return Scaffold(
      body: Container(
        color: const Color(0xFFF5F0E1),
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/2.jpg'),
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
                      child: Text(
                        '开始新样式',
                        style: TextStyle(color: Colors.amber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 打卡计划概览卡片
                CompactStyleOverview(currentStyle: _currentStyle),
                const SizedBox(height: 6),

                // 打卡样式的任务展示
                if (_currentStyle != null)
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
                        return TaskSimpleWidget(
                          title: task.title,
                          description: task.description,
                          imgUrl: task.image,
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 18),

                // 打卡记录日历
                Text('打卡记录总览', style: noteTitle),
                const SizedBox(height: 12),
                CheckinCalendar(
                  context: context,
                  style: _currentStyle,
                  records: _relatedRecords,
                ),
              ],
            ),
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
