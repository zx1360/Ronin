import 'package:go_router/go_router.dart';

import 'package:torrid/features/home/pages/home_page.dart';

import 'package:torrid/features/booklet/pages/booklet_page.dart';
import 'package:torrid/features/essay/pages/browse_page.dart';
import 'package:torrid/features/home/pages/splash_page.dart';
import 'package:torrid/features/read/pages/read_page.dart';
import 'package:torrid/features/library/pages/library_page.dart';
import 'package:torrid/features/others/pages/others_page.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';

import 'package:torrid/features/profile/pages/profile_page.dart';
import 'package:torrid/features/profile/pages/profile_second_shell.dart';
import 'package:torrid/features/profile/second_page/user/profile_user.dart';
import 'package:torrid/features/profile/second_page/preferences/background_setting_page.dart';
import 'package:torrid/features/profile/second_page/preferences/motto_setting_page.dart';

// 页面路径声明文件.
final List<RouteBase> routes = [
  // #### 无内容页面
  // 启动屏.
  GoRoute(
    path: "/splash",
    name: "splash",
    builder: (context, state) => const SplashPage(),
  ),
  // 栈底页: 桌面页
  // HOME页.
  GoRoute(
    path: "/home",
    name: "home",
    builder: (context, state) {
      final String? bgPath = state.uri.queryParameters['bgPath'];
      return HomePage(bgPath: bgPath);
    },
  ),

  // #### 主要页
  // 积微页, 打卡
  GoRoute(
    path: "/booklet",
    name: "booklet",
    builder: (context, state) => const BookletPage(),
  ),

  // 随笔页,
  GoRoute(
    path: "/essay",
    name: "essay",
    builder: (context, state) => const EssayBrowsePage(),
  ),

  // 待办页,
  GoRoute(
    path: "/library",
    name: "library",
    builder: (context, state) => const LibraryPage(),
  ),

  // 阅读页,
  GoRoute(
    path: "/news",
    name: "news",
    builder: (context, state) => const ReadPage(),
  ),

  // 其他页.
  GoRoute(
    path: "/others",
    name: "others",
    builder: (context, state) => const OthersPage(),
  ),

  // #### 个人页(偏好设置及数据相关)
  GoRoute(
    path: '/profile',
    name: 'profile',
    builder: (context, state) => const ProfilePage(),
    routes: [
      GoRoute(
        path: 'user',
        name: 'profile_user',
        builder: (context, state) => const ProfileUser(),
      ),
      // 背景图片设置
      GoRoute(
        path: 'background',
        name: 'profile_background',
        builder: (context, state) => const BackgroundSettingPage(),
      ),
      // 座右铭设置
      GoRoute(
        path: 'motto',
        name: 'profile_motto',
        builder: (context, state) => const MottoSettingPage(),
      ),
      ...profilePages.map(
        (config) => GoRoute(
          path: config.path,
          name: config.name,
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return ProfileDetailShell(
              title: extra?['title'] ?? config.title,
              child: config.builder(context),
            );
          },
        ),
      ),
    ],
  ),
];
