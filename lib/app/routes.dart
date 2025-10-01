import 'package:go_router/go_router.dart';

import 'package:torrid/features/home/pages/home_page.dart';

import 'package:torrid/features/booklet/pages/booklet_page.dart';
import 'package:torrid/features/essay/pages/essay_page.dart';
import 'package:torrid/features/news/news_page.dart';
import 'package:torrid/features/others/pages/others_page.dart';

import 'package:torrid/features/profile/pages/profile_page.dart';
import 'package:torrid/features/profile/pages/profile_detail_page.dart';
import 'package:torrid/features/profile/detail_pages/profile_user.dart';
import 'package:torrid/features/profile/detail_pages/profile_preferences.dart';
import 'package:torrid/features/profile/detail_pages/profile_data.dart';
import 'package:torrid/features/profile/detail_pages/profile_account.dart';
import 'package:torrid/features/profile/detail_pages/profile_abount.dart';
import 'package:torrid/features/profile/detail_pages/profile_help.dart';


// 页面路径声明文件.
final List<RouteBase> routes = [
  // #### 栈底页: 桌面页
  // HOME页.
  GoRoute(path: "/home", name: "home", builder: (context, state) => HomePage()),

  // #### 主要页
  // 积微页, 打卡/挑战.
  GoRoute(
    path: "/booklet",
    name: "booklet",
    builder: (context, state) => BookletPage(),
  ),

  // 随笔页,
  GoRoute(
    path: "/essay",
    name: "essay",
    builder: (context, state) => EssayPage(),
  ),

  // 早报页,
  GoRoute(path: "/news", name: "news", builder: (context, state) => NewsPage()),

  // 其他页.
  GoRoute(
    path: "/others",
    name: "others",
    builder: (context, state) => OthersPage(),
  ),

  // #### 个人页
  GoRoute(
    path: '/profile',
    name: 'profile',
    builder: (context, state) => ProfilePage(),
    routes: [
      // 个人二级页
      ShellRoute(
        builder: (context, state, child) {
          final params = state.extra as Map<String, dynamic>?;
          return ProfileDetailPage(title: params?['title'] ?? '', child: child);
        },
        routes: [
          GoRoute(
            path: 'user',
            name: 'profile_user',
            builder: (context, state) => ProfileUser(),
          ),
          GoRoute(
            path: 'preferences',
            name: 'profile_preferences',
            builder: (context, state) => ProfilePreferences(),
          ),
          GoRoute(
            path: 'data',
            name: 'profile_data',
            builder: (context, state) => ProfileData(),
          ),
          GoRoute(
            path: 'account',
            name: 'profile_account',
            builder: (context, state) => ProfileAccount(),
          ),
          GoRoute(
            path: 'help',
            name: 'profile_help',
            builder: (context, state) => ProfileHelp(),
          ),
          GoRoute(
            path: 'about',
            name: 'profile_about',
            builder: (context, state) => ProfileAbout(),
          ),
        ],
      ),
    ],
  ),
];
