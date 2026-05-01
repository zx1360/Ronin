import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/app/theme/theme_book.dart';

/// 默认背景组件
/// 供 SplashPage 和 HomePage 共用，确保视觉一致性
class DefaultBackground extends StatelessWidget {
  const DefaultBackground({super.key});

  @override
  Widget build(BuildContext context) {
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
            // 应用 logo 图标
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
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '热情生活，每一天',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义图片背景组件
/// 支持文件图片加载，加载失败时显示默认背景
class CustomImageBackground extends StatelessWidget {
  final File imageFile;

  const CustomImageBackground({
    super.key,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      imageFile,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => const DefaultBackground(),
    );
  }
}

/// 背景组件工厂
/// 根据是否有自定义图片文件返回相应背景组件
class BackgroundWidget extends StatelessWidget {
  final File? imageFile;

  const BackgroundWidget({
    super.key,
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    if (imageFile != null) {
      return CustomImageBackground(imageFile: imageFile!);
    }
    return const DefaultBackground();
  }
}
