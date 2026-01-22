import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'task_list.g.dart';

/// 智能列表类型枚举
/// 
/// 参考 Microsoft To-Do 的智能列表设计
enum SmartListType {
  /// 我的一天 - 今日任务
  myDay(
    id: 'smart_my_day',
    name: '我的一天',
    icon: Icons.wb_sunny_outlined,
    selectedIcon: Icons.wb_sunny,
  ),
  
  /// 重要 - 标记为重要的任务
  important(
    id: 'smart_important',
    name: '重要',
    icon: Icons.star_outline,
    selectedIcon: Icons.star,
  ),
  
  /// 计划内 - 有截止日期的任务
  planned(
    id: 'smart_planned',
    name: '计划内',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
  ),
  
  /// 全部 - 所有未完成任务
  all(
    id: 'smart_all',
    name: '全部',
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox,
  );

  final String id;
  final String name;
  final IconData icon;
  final IconData selectedIcon;

  const SmartListType({
    required this.id,
    required this.name,
    required this.icon,
    required this.selectedIcon,
  });
}

/// 任务列表颜色主题
@HiveType(typeId: 25)
enum ListThemeColor {
  @HiveField(0)
  blue,
  @HiveField(1)
  red,
  @HiveField(2)
  orange,
  @HiveField(3)
  green,
  @HiveField(4)
  purple,
  @HiveField(5)
  pink,
  @HiveField(6)
  teal,
  @HiveField(7)
  brown,
}

/// 获取列表主题颜色值
extension ListThemeColorExtension on ListThemeColor {
  Color get color {
    switch (this) {
      case ListThemeColor.blue:
        return const Color(0xFF2196F3);
      case ListThemeColor.red:
        return const Color(0xFFF44336);
      case ListThemeColor.orange:
        return const Color(0xFFFF9800);
      case ListThemeColor.green:
        return const Color(0xFF4CAF50);
      case ListThemeColor.purple:
        return const Color(0xFF9C27B0);
      case ListThemeColor.pink:
        return const Color(0xFFE91E63);
      case ListThemeColor.teal:
        return const Color(0xFF009688);
      case ListThemeColor.brown:
        return const Color(0xFF795548);
    }
  }
  
  Color get lightColor {
    switch (this) {
      case ListThemeColor.blue:
        return const Color(0xFFBBDEFB);
      case ListThemeColor.red:
        return const Color(0xFFFFCDD2);
      case ListThemeColor.orange:
        return const Color(0xFFFFE0B2);
      case ListThemeColor.green:
        return const Color(0xFFC8E6C9);
      case ListThemeColor.purple:
        return const Color(0xFFE1BEE7);
      case ListThemeColor.pink:
        return const Color(0xFFF8BBD9);
      case ListThemeColor.teal:
        return const Color(0xFFB2DFDB);
      case ListThemeColor.brown:
        return const Color(0xFFD7CCC8);
    }
  }
}

/// 任务列表数据模型
/// 
/// 用户创建的自定义任务列表，参考 MS To-Do 设计
@HiveType(typeId: 18)
class TaskList {
  /// 唯一标识符
  @HiveField(0)
  final String id;

  /// 列表名称
  @HiveField(1)
  final String name;

  /// 排序顺序
  @HiveField(2)
  final int order;

  /// 是否为默认列表（"任务"列表不可删除）
  @HiveField(3)
  final bool isDefault;

  /// 列表主题颜色
  @HiveField(4)
  final ListThemeColor themeColor;

  /// 列表图标（存储图标代码点）
  @HiveField(5)
  final int? iconCodePoint;

  /// 创建时间
  @HiveField(6)
  final DateTime createdAt;

  TaskList({
    required this.id,
    required this.name,
    required this.order,
    this.isDefault = false,
    this.themeColor = ListThemeColor.blue,
    this.iconCodePoint,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 获取列表图标
  IconData get icon {
    if (iconCodePoint != null) {
      return IconData(iconCodePoint!, fontFamily: 'MaterialIcons');
    }
    return Icons.list;
  }

  TaskList copyWith({
    String? id,
    String? name,
    int? order,
    bool? isDefault,
    ListThemeColor? themeColor,
    int? iconCodePoint,
    DateTime? createdAt,
    bool clearIconCodePoint = false,
  }) {
    return TaskList(
      id: id ?? this.id,
      name: name ?? this.name,
      order: order ?? this.order,
      isDefault: isDefault ?? this.isDefault,
      themeColor: themeColor ?? this.themeColor,
      iconCodePoint: clearIconCodePoint ? null : (iconCodePoint ?? this.iconCodePoint),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 当前视图类型（智能列表或自定义列表）
sealed class CurrentView {
  const CurrentView();
}

/// 智能列表视图
class SmartListView extends CurrentView {
  final SmartListType type;
  const SmartListView(this.type);
}

/// 自定义列表视图
class CustomListView extends CurrentView {
  final String listId;
  const CustomListView(this.listId);
}
