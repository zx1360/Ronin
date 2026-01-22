import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'todo_task.g.dart';

/// 任务优先级枚举
/// 
/// 参考 MS To-Do，简化为两级：普通和重要(星标)
@HiveType(typeId: 16)
enum Priority {
  @HiveField(0)
  @JsonValue('normal')
  normal,
  
  @HiveField(1)
  @JsonValue('important')
  important,
}

/// 重复类型枚举
@HiveType(typeId: 23)
enum RepeatType {
  @HiveField(0)
  @JsonValue('none')
  none,
  
  @HiveField(1)
  @JsonValue('daily')
  daily,
  
  @HiveField(2)
  @JsonValue('weekdays')
  weekdays,
  
  @HiveField(3)
  @JsonValue('weekly')
  weekly,
  
  @HiveField(4)
  @JsonValue('monthly')
  monthly,
  
  @HiveField(5)
  @JsonValue('yearly')
  yearly,
}

/// 子任务/步骤模型
@JsonSerializable()
@HiveType(typeId: 24)
class TodoStep {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isDone;

  const TodoStep({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  TodoStep copyWith({
    String? id,
    String? title,
    bool? isDone,
  }) {
    return TodoStep(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  factory TodoStep.fromJson(Map<String, dynamic> json) =>
      _$TodoStepFromJson(json);
  Map<String, dynamic> toJson() => _$TodoStepToJson(this);
}

/// Todo 任务数据模型
/// 
/// 参考 Microsoft To-Do 设计，包含以下核心功能：
/// - 基础信息：标题、备注
/// - 状态管理：完成状态、重要标记、添加到我的一天
/// - 时间管理：截止日期、提醒时间、重复设置
/// - 子任务：步骤列表
@JsonSerializable()
@HiveType(typeId: 19)
class TodoTask {
  /// 唯一标识符
  @HiveField(0)
  final String id;

  /// 任务标题
  @HiveField(1)
  final String title;

  /// 任务备注/描述
  @HiveField(2)
  final String? note;

  /// 是否已完成
  @HiveField(3)
  final bool isDone;

  /// 截止日期
  @HiveField(4)
  final DateTime? dueDate;

  /// 提醒时间
  @HiveField(5)
  final DateTime? reminder;

  /// 优先级（普通/重要）
  @HiveField(6)
  final Priority priority;

  /// 创建时间
  @HiveField(7)
  final DateTime createdAt;

  /// 完成时间
  @HiveField(8)
  final DateTime? completedAt;

  /// 是否添加到"我的一天"
  @HiveField(9)
  final bool isMyDay;

  /// "我的一天"添加日期（用于判断是否过期）
  @HiveField(10)
  final DateTime? myDayDate;

  /// 重复类型
  @HiveField(11)
  final RepeatType repeatType;

  /// 子任务/步骤列表
  @HiveField(12)
  final List<TodoStep> steps;

  /// 所属列表 ID
  @HiveField(13)
  final String listId;

  TodoTask({
    required this.id,
    required this.title,
    this.note,
    this.isDone = false,
    this.dueDate,
    this.reminder,
    this.priority = Priority.normal,
    DateTime? createdAt,
    this.completedAt,
    this.isMyDay = false,
    this.myDayDate,
    this.repeatType = RepeatType.none,
    this.steps = const [],
    required this.listId,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 是否标记为重要
  bool get isImportant => priority == Priority.important;

  /// 今日是否在"我的一天"中（检查日期是否为今天）
  bool get isInMyDayToday {
    if (!isMyDay || myDayDate == null) return false;
    final now = DateTime.now();
    return myDayDate!.year == now.year &&
        myDayDate!.month == now.month &&
        myDayDate!.day == now.day;
  }

  /// 是否已过期
  bool get isOverdue {
    if (dueDate == null || isDone) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  /// 是否今天截止
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  /// 已完成的步骤数
  int get completedStepsCount => steps.where((s) => s.isDone).length;

  /// 步骤完成进度文本
  String get stepsProgressText => '$completedStepsCount/${steps.length}';

  TodoTask copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
    DateTime? dueDate,
    DateTime? reminder,
    Priority? priority,
    DateTime? createdAt,
    DateTime? completedAt,
    bool? isMyDay,
    DateTime? myDayDate,
    RepeatType? repeatType,
    List<TodoStep>? steps,
    String? listId,
    // 允许清除可选字段
    bool clearNote = false,
    bool clearDueDate = false,
    bool clearReminder = false,
    bool clearCompletedAt = false,
    bool clearMyDayDate = false,
  }) {
    return TodoTask(
      id: id ?? this.id,
      title: title ?? this.title,
      note: clearNote ? null : (note ?? this.note),
      isDone: isDone ?? this.isDone,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminder: clearReminder ? null : (reminder ?? this.reminder),
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      isMyDay: isMyDay ?? this.isMyDay,
      myDayDate: clearMyDayDate ? null : (myDayDate ?? this.myDayDate),
      repeatType: repeatType ?? this.repeatType,
      steps: steps ?? this.steps,
      listId: listId ?? this.listId,
    );
  }

  factory TodoTask.fromJson(Map<String, dynamic> json) =>
      _$TodoTaskFromJson(json);
  Map<String, dynamic> toJson() => _$TodoTaskToJson(this);

  // 兼容旧代码的 getter
  @Deprecated('Use note instead')
  String? get desc => note;
}
