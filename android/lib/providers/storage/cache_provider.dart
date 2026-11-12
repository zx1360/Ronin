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
    Future.microtask(() async {
      if (ref.mounted) await refresh();
    });
    return CacheState(config: CacheConfig.fromPrefs());
  }

  /// 刷新缓存信息
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearMessage: true);

    try {
      final info = await const CacheService().getCacheInfo();
      if (ref.mounted) state = state.copyWith(info: info, isLoading: false);
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, message: '获取缓存信息失败: $e');
      }
    }
  }

  /// 更新缓存配置
  Future<void> updateConfig(CacheConfig newConfig) async {
    await newConfig.saveToPrefs();
    if (!ref.mounted) return;
    state = state.copyWith(config: CacheConfig.fromPrefs(), message: '配置已更新');
  }

  Future<void> clearImageCache() =>
      _clear(const CacheService().clearImageCache, '图片缓存已清理');

  Future<void> clearTempCache() =>
      _clear(const CacheService().clearTempCache, '临时文件已清理');

  Future<void> clearAllCache() =>
      _clear(const CacheService().clearAllCache, '所有缓存已清理');

  Future<void> _clear(Future<void> Function() clear, String success) async {
    if (state.isClearing) return;
    state = state.copyWith(isClearing: true, clearMessage: true);
    try {
      await clear();
      final info = await const CacheService().getCacheInfo();
      if (ref.mounted) {
        state = state.copyWith(info: info, isClearing: false, message: success);
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(isClearing: false, message: '清理失败：$error');
      }
    }
  }
}
