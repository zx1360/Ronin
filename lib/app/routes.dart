import 'package:go_router/go_router.dart';

import 'package:torrid/features/home/pages/home_page.dart';

import 'package:torrid/features/booklet/pages/booklet_page.dart';
import 'package:torrid/features/essay/pages/essay_browse_page.dart';
import 'package:torrid/features/home/pages/splash_page.dart';
import 'package:torrid/features/news/news_page.dart';
import 'package:torrid/features/others/pages/others_page.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';

import 'package:torrid/features/profile/pages/profile_page.dart';
import 'package:torrid/features/profile/pages/profile_detail_shell.dart';
import 'package:torrid/features/profile/detail_pages/profile_user.dart';

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
      final int bgIndex =
          int.tryParse(state.uri.queryParameters['bgIndex'] ?? "") ?? 1;
      return HomePage(bgIndex: bgIndex);
    },
  ),

  // #### 主要页
  // 积微页, 打卡/挑战.
  GoRoute(
    path: "/booklet",
    name: "booklet",
    builder: (context, state) => const BookletPage(),
  ),

  // 随笔页,
  GoRoute(
    path: "/essay",
    name: "essay",
    builder: (context, state) => EssayBrowsePage(),
  ),

  // 早报页,
  GoRoute(
    path: "/news",
    name: "news",
    builder: (context, state) => const NewsPage(),
  ),

  // 其他页.
  GoRoute(
    path: "/others",
    name: "others",
    builder: (context, state) => const OthersPage(),
  ),

  // #### 个人页
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
