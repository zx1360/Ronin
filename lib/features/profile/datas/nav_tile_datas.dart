import 'package:flutter/material.dart';
import 'package:torrid/features/profile/widgets/nav_tile.dart';

class NavTileDatas {
  static List<NavInfo> get datas => [
    NavInfo(title: "首选项", subtitle: "自定义背景图片、标题", icon: Icons.room_preferences, childRouteName: "profile_preferences"),
    NavInfo(title: "数据", subtitle: "备份或同步", icon: Icons.laptop_chromebook_outlined, childRouteName: "profile_data"),
    NavInfo(title: "账户?", subtitle: "管理您的账户信息", icon: Icons.account_circle, childRouteName: "profile_account"),
    NavInfo(title: "帮助中心", subtitle: "获取使用帮助", icon: Icons.help, childRouteName: "profile_help"),
    NavInfo(title: "关于应用", subtitle: "版本1.0.0", icon: Icons.info, childRouteName: "profile_about"),
  ];
}