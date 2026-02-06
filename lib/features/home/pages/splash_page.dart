import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

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
      HiveService.initGallery(),
    ]);
    if (mounted) {
      context.replaceNamed("home", queryParameters: {"bgIndex": randomIndex});
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.light, 
      statusBarColor: Colors.transparent,
    ));

    return Container(
      constraints: BoxConstraints.expand(),
      child: Image.asset("assets/images/$randomIndex.jpg", fit: BoxFit.cover),
    );
  }
}
