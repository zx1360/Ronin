import 'package:flutter/material.dart';

Widget createBottomNavBar(int curIndex, void Function(int) switchIndex) {
  return BottomNavigationBar(
  showUnselectedLabels: false,
  currentIndex: curIndex,
  onTap: switchIndex,
  // 强制设置背景色，覆盖主题的背景色
  backgroundColor: Colors.white70,
  // 显式设置选中和未选中颜色
  selectedItemColor: Colors.yellow.shade700,
  unselectedItemColor: Colors.grey.shade500,
  // 强制设置阴影
  elevation: 4,
  // 显式设置选中标签样式
  selectedLabelStyle: const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: null, // 保持与selectedItemColor一致
  ),
  // 覆盖主题中的图标样式
  unselectedIconTheme: IconThemeData(
    color: Colors.grey.shade500,
    size: 22,
  ),
  selectedIconTheme: IconThemeData(
    color: Colors.yellow.shade700,
    size: 22,
  ),
  // 移除可能的主题影响的类型
  type: BottomNavigationBarType.fixed,
  items: <BottomNavigationBarItem>[
    BottomNavigationBarItem(
      icon: const Icon(Icons.book, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.book, size: 22, color: Colors.yellow.shade700),
      ),
      label: "日常打卡",
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.task, size: 22),
      activeIcon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.yellow.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.task, size: 22, color: Colors.yellow.shade700),
      ),
      label: "攻克难关",
    ),
  ],
);
}
