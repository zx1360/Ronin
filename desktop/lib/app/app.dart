import 'package:flutter/material.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/app/router.dart';

// PC启动时的ui应用
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "northstar 北极星",
      theme: AppTheme.dark(),
      
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}