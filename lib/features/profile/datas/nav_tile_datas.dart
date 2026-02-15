import 'package:flutter/material.dart';
import 'package:torrid/features/profile/second_page/about/profile_about.dart';
import 'package:torrid/features/profile/second_page/data/data_transfer.dart';
import 'package:torrid/features/profile/second_page/preferences/profile_preferences.dart';


// 页面配置模型：统一管理页面元信息
class ProfilePageConfig {
  final String name; // 路由名称
  final String path; // 路由路径
  final String title; // 页面标题
  final String subtitle; // 列表项副标题
  final IconData icon; // 列表项图标
  final WidgetBuilder builder; // 页面构建器

  const ProfilePageConfig({
    required this.name,
    required this.path,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}

// 所有页面的配置列表：集中管理路由和页面信息
final List<ProfilePageConfig> profilePages = [
  // 其他设置
  ProfilePageConfig(
    name: 'profile_preferences',
    path: 'preferences',
    title: '偏好设置',
    subtitle: '自定义偏好配置',
    icon: Icons.room_preferences,
    builder: (context) => const ProfilePreferences(),
  ),
  ProfilePageConfig(
    name: 'profile_data',
    path: 'data',
    title: '数据',
    subtitle: '备份或同步',
    icon: Icons.laptop_chromebook_outlined,
    builder: (context) => const DataTransferPage(),
  ),
  // 关于
  ProfilePageConfig(
    name: 'profile_about',
    path: 'about',
    title: '关于应用',
    subtitle: '阅读在线应用文档',
    icon: Icons.info,
    builder: (context) => const ProfileAbout(),
  ),
];
