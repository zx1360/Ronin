import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/features/essay/services/essay_hive_service.dart';
import 'package:torrid/features/others/comic/services/comic_hive_service.dart';
import 'package:torrid/features/others/tuntun/services/tuntun_hive_service.dart';

// 启动屏, 最快速度显示
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  // 随机展示一个背景图片. 并在之后传给HomePage.
  final randomIndex = (Random().nextInt(6) + 1).toString();

  @override
  void initState() {
    print("__1");
    super.initState();
    _initialize();
  }

  // 初始化操作, 完成后跳转到HomePage.
  Future<void> _initialize() async {
    // 初始化操作.
    await Hive.initFlutter();
    await Future.wait([
      IoService.initDirs(),

      BookletHiveService.init(),
      EssayHiveService.init(),
      TuntunHiveService.init(),
      ComicHiveService.init(),
    ]);
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
