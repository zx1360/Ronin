import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app_theme.dart';
import 'package:torrid/router.dart';

import 'package:torrid/services/common/hive_service.dart';
import 'package:torrid/services/booklet/booklet_hive_service.dart';
import 'package:torrid/services/essay/essay_hive_service.dart';
import 'package:torrid/services/tuntun/tuntun_hive_service.dart';

void main() async {
  // // 1.确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  // // 2.其他初始化(Hive)
  await HiveService.init();
  
  await BookletHiveService.init();
  await EssayHiveService.init();
  await TuntunHiveService.init();

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "torrid",
      theme: AppTheme.lightTheme(),

      // 关联路由配置
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
    );
  }
}
