import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';

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
      HiveService.initGallery(),
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
    // 如果有自定义背景图且文件存在
    if (_backgroundFile != null) {
      return Image.file(
        _backgroundFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultBackground(),
      );
    }
    // 使用默认背景
    return _buildDefaultBackground();
  }

  /// 默认简约背景
  Widget _buildDefaultBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withAlpha(200),
            AppTheme.primaryContainer,
            AppTheme.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用logo或图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 60,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'TORRID',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '热情生活，每一天',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
