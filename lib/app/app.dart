import 'package:flutter/material.dart';

import 'package:torrid/app/theme_book.dart';
import 'package:torrid/app/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "torrid",
      theme: AppTheme.bookTheme(),

      // 关联路由配置
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}