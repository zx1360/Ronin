import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:torrid/providers/server_connect/server_conn_provider.dart';

import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/services/storage/hive_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';

// 启动屏, 最快速度显示
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  // 随机展示一个背景图片. 并在之后传给HomePage.
  final randomIndex = (Random().nextInt(6) + 1).toString();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // 初始化操作, 完成后跳转到HomePage.
  Future<void> _initialize() async {
    // 初始化操作.
    await Hive.initFlutter();
    await PrefsService().initPrefs();
    await Future.wait([
      IoService.initDirs(),

      HiveService.init(),
      // TODO: 改到特定页面再加载, 处理好时机关系.
      HiveService.initComic(),
      HiveService.initTuntun(),
    ]);
    ref.watch(serverConnectorProvider.notifier).getPcAddr();
    if (mounted) {
      context.replaceNamed("home", queryParameters: {"bgIndex": randomIndex});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      child: Image.asset("assets/images/$randomIndex.jpg", fit: BoxFit.cover),
    );
  }
}
