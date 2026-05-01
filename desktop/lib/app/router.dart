import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:northstar/app/routes.dart';
import 'package:northstar/shared/widgets/shell/shell_page.dart';

final GoRouter router = GoRouter(
  initialLocation: "/dashboard",
  routes: [
    StatefulShellRoute.indexedStack(
      branches: [
        for (final route in routes)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: route.path,
                name: route.name,
                builder: route.builder,
              ),
            ],
          ),
      ],
      builder: (context, state, navigationShell) {
        return ShellPage(navigationShell: navigationShell);
      },
    ),
  ],
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text("当前页面不存在!"))),
      
);
