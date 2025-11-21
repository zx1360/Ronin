// 全局常量
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const int maxTaskCount = 5; // 任务数量上限
const double dropdownMaxHeight = 200; // 下拉框最大高度
const List<Color> checkInColors = [
  Color(0xFFE8E2D3), // 1.无记录
  Color(0xFFA3D9A5), // 2.全完成
  Color(0xFFC4E17F), // 3. 差1个（浅黄绿色，接近完成，轻微提醒）
  Color(0xFFFFE066), // 4. 差2个（浅黄色，中等差距，普通提醒）
  Color(0xFFFFAB91), // 5. 差3个（浅橙色，较大差距，强烈提醒）
  Color(0xFFEF5350), // 6. 差4个（红色，差距极大，紧急警示）
];
const Color messageMarkerColor = Color(0xFF8B5A2B); // 留言标记色

// 字体样式（全局统一）
final TextStyle noteText = TextStyle(
  color: const Color(0xFF3A2E2F),
  fontSize: 14,
);
final TextStyle noteTitle = TextStyle(
  color: const Color(0xFF8B5A2B),
  fontSize: 16,
  fontWeight: FontWeight.bold,
);
final TextStyle noteSmall = TextStyle(
  color: const Color(0xFF8B7355),
  fontSize: 12,
);

// 日期格式化器
final DateFormat fullDateFormatter = DateFormat('yyyy年MM月dd日 EEEE');
final DateFormat monthFormatter = DateFormat('yyyy年MM月');
final DateFormat dayFormatter = DateFormat('d');
