import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/routes.dart';

final GoRouter router = GoRouter(
  initialLocation: "/home",
  routes: routes,
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text("页面不存在!"))),
);
