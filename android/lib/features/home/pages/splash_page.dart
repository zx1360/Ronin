import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/network/cert_trust.dart';
import 'package:torrid/core/services/storage/cache_service.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/features/comic/providers/download_task_provider.dart';
import 'package:torrid/features/home/widgets/default_background.dart';
import 'package:torrid/features/trace/trace_store.dart';
import 'package:torrid/features/trace/trace_timing.dart';

/// 启动屏和首页共用同一张自定义背景图。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  /// 是否有自定义背景图（null=尚未判定，等 prefs 就绪后确定）
  bool? _hasCustomBg;

  String? _backgroundPath;

  File? _backgroundFile;
  Object? _startupError;
  bool _initializing = false;

  late final AnimationController _loadingAnimCtrl;

  @override
  void initState() {
    super.initState();

    _loadingAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _initialize();
  }

  @override
  void dispose() {
    _loadingAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    setState(() => _startupError = null);
    if (!_loadingAnimCtrl.isAnimating) _loadingAnimCtrl.repeat(reverse: true);
    try {
      await CertTrust.init();
      await PrefsService().initPrefs();
      try {
        await ref.read(appDatabaseProvider).initialize();
      } catch (_) {
        if (mounted) ref.invalidate(appDatabaseProvider);
        rethrow;
      }
      await ref.read(comicDownloadTasksProvider.notifier).initialize();
      unawaited(const CacheService().performStartupCleanup());

      final service = PersonalizationService();
      _backgroundPath = service.getRandomBackgroundImage();
      _backgroundFile = _backgroundPath == null
          ? null
          : await IoService.getImageFile(_backgroundPath!);
      _hasCustomBg = _backgroundFile != null;
      if (mounted) await recoverTrace(context, ref.read(traceStoreProvider));
      if (mounted) {
        context.replaceNamed(
          "home",
          queryParameters: {"bgPath": _backgroundPath ?? ""},
        );
      }
    } catch (error, stack) {
      AppLogger().error('本地数据初始化失败', error, stack);
      if (mounted) {
        _loadingAnimCtrl.stop();
        setState(() => _startupError = error);
      }
    } finally {
      _initializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );

    final showLoadingHint = _hasCustomBg == true;

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackground(),
        if (showLoadingHint)
          Positioned(right: 28, bottom: 48, child: _buildLoadingIndicator()),
        if (_startupError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('本地数据初始化失败，已有数据未被清除。'),
                      const SizedBox(height: 12),
                      Text(
                        '$_startupError',
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _initialize,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackground() {
    if (_hasCustomBg != true) {
      return const BackgroundWidget();
    }

    if (_backgroundFile != null) {
      return Image.file(
        _backgroundFile!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(color: AppTheme.surface);
  }

  Widget _buildLoadingIndicator() {
    return FadeTransition(
      opacity: _loadingAnimCtrl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '加载中',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            letterSpacing: 1.2,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
