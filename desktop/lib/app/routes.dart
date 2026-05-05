import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:northstar/ui/ops/pages/dashboard_page.dart';
import 'package:northstar/ui/ops/pages/comics_page.dart';
import 'package:northstar/ui/ops/pages/task_manager_page.dart';
import 'package:northstar/ui/ops/pages/logs_page.dart';
import 'package:northstar/ui/ops/pages/settings_page.dart';
import 'package:northstar/features/help/pages/help_page.dart';


// 定义路由数据模型
class AppRoute {
  final String path;
  final String name;
  final IconData icon;
  final Widget Function(BuildContext, GoRouterState) builder;

  const AppRoute({
    required this.path,
    required this.name,
    required this.icon,
    required this.builder,
  });
}

// 所有路由定义: 1仪表盘, 2漫画, 3日志, 4任务, 5设置
final List<AppRoute> routes = [
  // Dashboard
  AppRoute(
    path: '/dashboard',
    name: 'dashboard',
    icon: IconData(0xe625, fontFamily: 'iconfont'),
    builder: (context, state) => const DashboardPage(),
  ),

  // 漫画资源管理
  AppRoute(
    path: '/comics',
    name: 'comics',
    icon: Icons.menu_book_rounded,
    builder: (context, state) => const ComicsPage(),
  ),

  // 日志
  AppRoute(
    path: '/logs',
    name: 'logs',
    icon: IconData(0xe627, fontFamily: 'iconfont'),
    builder: (context, state) => const LogsPage(),
  ),

  // 任务管理
  AppRoute(
    path: '/tasks',
    name: 'tasks',
    icon: Icons.task_alt_rounded,
    builder: (context, state) => const TaskManagerPage(),
  ),

  // 设置
  AppRoute(
    path: '/settings',
    name: 'settings',
    icon: Icons.settings,
    builder: (context, state) => const SettingsPage(),
  ),
  
  // 帮助页
  AppRoute(
    path: '/help',
    name: 'help',
    icon: IconData(0xe60a, fontFamily: 'iconfont'),
    builder: (context, state) => const HelpPage(),
  ),
];
