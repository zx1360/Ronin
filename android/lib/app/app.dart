import 'package:flutter/material.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/app/routes/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "torrid",
      theme: AppTheme.bookTheme(),

      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}