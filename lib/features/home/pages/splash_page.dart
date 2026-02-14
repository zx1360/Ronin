import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/features/home/widgets/default_background.dart';

// 启动屏, 最快速度显示
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  // 背景图片路径（相对路径，为null时使用默认背景）
  String? _backgroundPath;
  File? _backgroundFile;

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
    ]);

    // 获取个性化背景图
    final personalizationService = PersonalizationService();
    _backgroundPath = personalizationService.getRandomBackgroundImage();
    
    if (_backgroundPath != null) {
      _backgroundFile = await IoService.getImageFile(_backgroundPath!);
    }
    
    if (mounted) {
      setState(() {});
      // 稍微延迟以显示背景
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        context.replaceNamed(
          "home",
          queryParameters: {"bgPath": _backgroundPath ?? ""},
        );
      }
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
      constraints: const BoxConstraints.expand(),
      child: _buildBackground(),
    );
  }

  /// 构建背景
  Widget _buildBackground() {
    return BackgroundWidget(imageFile: _backgroundFile);
  }
}
