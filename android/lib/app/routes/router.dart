import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/routes/routes.dart';

final GoRouter router = GoRouter(
  initialLocation: "/splash",
  routes: routes,
  errorBuilder: (context, state) =>
      Scaffold(body: Center(child: Text("页面不存在!"))),
);
