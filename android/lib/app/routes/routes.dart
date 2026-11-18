import 'package:go_router/go_router.dart';

import 'package:torrid/features/home/back_handler.dart';
import 'package:torrid/features/home/pages/home_page.dart';

import 'package:torrid/features/booklet/pages/booklet_page.dart';
import 'package:torrid/features/chat/models/chat_models.dart';
import 'package:torrid/features/chat/pages/chat_page.dart';
import 'package:torrid/features/chat/pages/chat_settings_page.dart';
import 'package:torrid/features/chat/pages/review_page.dart';
import 'package:torrid/features/chat/pages/review_presets_page.dart';
import 'package:torrid/features/essay/pages/browse_page.dart';
import 'package:torrid/features/home/pages/splash_page.dart';
import 'package:torrid/features/trace/trace_page.dart';
import 'package:torrid/features/others/pages/others_page.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';

import 'package:torrid/features/profile/pages/profile_page.dart';
import 'package:torrid/features/profile/pages/profile_second_shell.dart';
import 'package:torrid/features/profile/second_page/user/profile_user.dart';
import 'package:torrid/features/profile/second_page/preferences/background_setting_page.dart';
import 'package:torrid/features/profile/second_page/preferences/motto_setting_page.dart';

final List<RouteBase> routes = [
  GoRoute(
    path: "/splash",
    name: "splash",
    builder: (context, state) => const BackHandler(child: SplashPage()),
  ),
  GoRoute(
    path: "/home",
    name: "home",
    builder: (context, state) {
      final String? bgPath = state.uri.queryParameters['bgPath'];
      return HomePage(bgPath: bgPath);
    },
  ),

  GoRoute(
    path: "/booklet",
    name: "booklet",
    builder: (context, state) => const BookletPage(),
  ),

  GoRoute(
    path: "/essay",
    name: "essay",
    builder: (context, state) => const EssayBrowsePage(),
  ),

  GoRoute(
    path: "/chat",
    name: "chat",
    builder: (context, state) {
      final extra = state.extra;
      return ChatPage(args: extra is ChatLaunchArgs ? extra : null);
    },
    routes: [
      GoRoute(
        path: "settings",
        name: "chat_settings",
        builder: (context, state) => const ChatSettingsPage(),
      ),
      GoRoute(
        path: "review",
        name: "chat_review",
        builder: (context, state) => const ReviewPage(),
      ),
      GoRoute(
        path: "review/presets",
        name: "chat_review_presets",
        builder: (context, state) => const ReviewPresetsPage(),
      ),
    ],
  ),

  GoRoute(
    path: '/trace',
    name: 'trace',
    builder: (context, state) => const TracePage(),
  ),

  GoRoute(
    path: "/others",
    name: "others",
    builder: (context, state) => const OthersPage(),
  ),

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
      GoRoute(
        path: 'background',
        name: 'profile_background',
        builder: (context, state) => const BackgroundSettingPage(),
      ),
      GoRoute(
        path: 'motto',
        name: 'profile_motto',
        builder: (context, state) => const MottoSettingPage(),
      ),
      ...settingPages.map(
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
      ...aboutPages.map(
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
