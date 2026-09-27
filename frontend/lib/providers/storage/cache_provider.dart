/// 缓存管理状态提供器
///
/// 提供缓存信息状态和清理操作
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/cache_service.dart';

part 'cache_provider.g.dart';

/// 缓存信息状态
class CacheState {
  final CacheInfo info;
  final CacheConfig config;
  final bool isLoading;
  final bool isClearing;
  final String? message;

  const CacheState({
    this.info = const CacheInfo(),
    this.config = const CacheConfig(),
    this.isLoading = false,
    this.isClearing = false,
    this.message,
  });

  CacheState copyWith({
    CacheInfo? info,
    CacheConfig? config,
    bool? isLoading,
    bool? isClearing,
    String? message,
    bool clearMessage = false,
  }) {
    return CacheState(
      info: info ?? this.info,
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isClearing: isClearing ?? this.isClearing,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// 缓存管理Provider
@Riverpod(keepAlive: true)
class CacheManager extends _$CacheManager {
  @override
  CacheState build() {
    // 初始加载缓存信息
    Future.microtask(() => refresh());
    return CacheState(config: CacheService().config);
  }

  /// 刷新缓存信息
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      final info = await CacheService().getCacheInfo();
      final config = CacheService().config;
      state = state.copyWith(info: info, config: config, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        message: '获取缓存信息失败: $e',
      );
    }
  }

  /// 更新缓存配置
  Future<void> updateConfig(CacheConfig newConfig) async {
    await CacheService().updateConfig(newConfig);
    state = state.copyWith(config: newConfig, message: '配置已更新');
  }

  /// 清理图片缓存
  Future<void> clearImageCache() async {
    state = state.copyWith(isClearing: true, clearMessage: true);

    try {
      await CacheService().clearImageCache();
      await refresh();
      state = state.copyWith(isClearing: false, message: '图片缓存已清理');
    } catch (e) {
      state = state.copyWith(
        isClearing: false,
        message: '清理失败: $e',
      );
    }
  }

  /// 清理临时缓存
  Future<void> clearTempCache() async {
    state = state.copyWith(isClearing: true, clearMessage: true);

    try {
      await CacheService().clearTempCache();
      await refresh();
      state = state.copyWith(isClearing: false, message: '临时缓存已清理');
    } catch (e) {
      state = state.copyWith(
        isClearing: false,
        message: '清理失败: $e',
      );
    }
  }

  /// 清理其他缓存
  Future<void> clearOtherCache() async {
    state = state.copyWith(isClearing: true, clearMessage: true);

    try {
      await CacheService().clearOtherCache();
      await refresh();
      state = state.copyWith(isClearing: false, message: '其他缓存已清理');
    } catch (e) {
      state = state.copyWith(
        isClearing: false,
        message: '清理失败: $e',
      );
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    state = state.copyWith(isClearing: true, clearMessage: true);

    try {
      await CacheService().clearAllCache();
      await refresh();
      state = state.copyWith(isClearing: false, message: '所有缓存已清理');
    } catch (e) {
      state = state.copyWith(
        isClearing: false,
        message: '清理失败: $e',
      );
    }
  }
}
