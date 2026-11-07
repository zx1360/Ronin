import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/app/theme/theme_book.dart';

class DefaultBackground extends StatelessWidget {
  final bool showBrand;
  const DefaultBackground({super.key, this.showBrand = true});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.primary.withAlpha(200),
          AppTheme.primaryContainer,
          AppTheme.surface,
        ],
        stops: const [0, .5, 1],
      ),
    ),
    child: showBrand ? const Center(child: TorridBrand()) : null,
  );
}

class TorridBrand extends StatelessWidget {
  const TorridBrand({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
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
        child: const Icon(
          Icons.local_fire_department_rounded,
          size: 60,
          color: AppTheme.primary,
        ),
      ),
      const SizedBox(height: 24),
      const Text(
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
      const Text(
        '热情生活，每一天',
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.onSurfaceVariant,
          letterSpacing: 2,
          decoration: TextDecoration.none,
        ),
      ),
    ],
  );
}

class BackgroundWidget extends StatelessWidget {
  final File? imageFile;
  final bool showBrand;
  const BackgroundWidget({super.key, this.imageFile, this.showBrand = true});

  @override
  Widget build(BuildContext context) {
    final fallback = DefaultBackground(showBrand: showBrand);
    return imageFile == null
        ? fallback
        : Image.file(
            imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}
