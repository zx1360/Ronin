/// 缓存管理服务
///
/// 提供应用缓存的统一管理，包括：
/// - 缓存大小计算
/// - 自动清理（按时间/容量）
/// - 手动清理
library;

import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

/// 缓存配置
class CacheConfig {
  /// 缓存过期天数（默认7天）
  final int expireDays;

  /// 缓存容量上限（MB）（默认500MB）
  final int maxSizeMB;

  /// 是否启用自动清理
  final bool autoCleanEnabled;

  const CacheConfig({
    this.expireDays = 7,
    this.maxSizeMB = 500,
    this.autoCleanEnabled = true,
  });

  /// 从偏好设置加载配置
  factory CacheConfig.fromPrefs() {
    final prefs = PrefsService().prefs;
    return CacheConfig(
      expireDays: prefs.getInt('cache_expire_days') ?? 7,
      maxSizeMB: prefs.getInt('cache_max_size_mb') ?? 500,
      autoCleanEnabled: prefs.getBool('cache_auto_clean') ?? true,
    );
  }

  /// 保存配置到偏好设置
  Future<void> saveToPrefs() async {
    final prefs = PrefsService().prefs;
    await prefs.setInt('cache_expire_days', expireDays);
    await prefs.setInt('cache_max_size_mb', maxSizeMB);
    await prefs.setBool('cache_auto_clean', autoCleanEnabled);
  }

  CacheConfig copyWith({
    int? expireDays,
    int? maxSizeMB,
    bool? autoCleanEnabled,
  }) {
    return CacheConfig(
      expireDays: expireDays ?? this.expireDays,
      maxSizeMB: maxSizeMB ?? this.maxSizeMB,
      autoCleanEnabled: autoCleanEnabled ?? this.autoCleanEnabled,
    );
  }
}

/// 缓存信息
class CacheInfo {
  /// 图片缓存大小（字节）
  final int imageCacheSize;

  /// 临时文件缓存大小（字节）
  final int tempCacheSize;

  /// 其他缓存大小（字节）
  final int otherCacheSize;

  const CacheInfo({
    this.imageCacheSize = 0,
    this.tempCacheSize = 0,
    this.otherCacheSize = 0,
  });

  /// 总缓存大小（字节）
  int get totalSize => imageCacheSize + tempCacheSize + otherCacheSize;

  /// 获取格式化的大小字符串
  String get formattedTotal => _formatSize(totalSize);
  String get formattedImageCache => _formatSize(imageCacheSize);
  String get formattedTempCache => _formatSize(tempCacheSize);
  String get formattedOtherCache => _formatSize(otherCacheSize);

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 缓存管理服务
class CacheService {
  // 单例模式
  static final CacheService _instance = CacheService._();
  CacheService._();
  factory CacheService() => _instance;

  final _logger = AppLogger();

  /// 缓存配置
  CacheConfig _config = const CacheConfig();
  CacheConfig get config => _config;

  /// 初始化服务
  Future<void> init() async {
    _config = CacheConfig.fromPrefs();
    _logger.info('缓存服务初始化完成，配置: 过期天数=${_config.expireDays}, '
        '容量上限=${_config.maxSizeMB}MB, 自动清理=${_config.autoCleanEnabled}');
  }

  /// 更新配置
  Future<void> updateConfig(CacheConfig newConfig) async {
    _config = newConfig;
    await _config.saveToPrefs();
    _logger.info('缓存配置已更新');
  }

  /// 获取缓存信息
  Future<CacheInfo> getCacheInfo() async {
    try {
      final imageCacheSize = await _getImageCacheSize();
      final tempCacheSize = await _getTempCacheSize();
      final otherCacheSize = await _getOtherCacheSize();

      return CacheInfo(
        imageCacheSize: imageCacheSize,
        tempCacheSize: tempCacheSize,
        otherCacheSize: otherCacheSize,
      );
    } catch (e) {
      _logger.error('获取缓存信息失败: $e');
      return const CacheInfo();
    }
  }

  /// 获取图片缓存大小
  Future<int> _getImageCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final imageCacheDir =
          Directory('${cacheDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        return await _calculateDirSize(imageCacheDir);
      }
      return 0;
    } catch (e) {
      _logger.warning('获取图片缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取临时文件缓存大小
  Future<int> _getTempCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      int total = 0;

      await for (final entity in tempDir.list()) {
        if (entity is File) {
          total += await entity.length();
        } else if (entity is Directory &&
            !entity.path.contains('libCachedImageData')) {
          total += await _calculateDirSize(entity);
        }
      }

      return total;
    } catch (e) {
      _logger.warning('获取临时缓存大小失败: $e');
      return 0;
    }
  }

  /// 获取其他缓存大小（应用缓存目录）
  Future<int> _getOtherCacheSize() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      return await _calculateDirSize(cacheDir);
    } catch (e) {
      _logger.warning('获取其他缓存大小失败: $e');
      return 0;
    }
  }

  /// 计算目录大小
  Future<int> _calculateDirSize(Directory dir) async {
    int total = 0;
    try {
      if (!await dir.exists()) return 0;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // 忽略无法访问的文件
          }
        }
      }
    } catch (e) {
      _logger.warning('计算目录大小失败 ${dir.path}: $e');
    }
    return total;
  }

  /// 执行启动时的自动检查清理
  Future<void> performStartupCleanup() async {
    if (!_config.autoCleanEnabled) {
      _logger.info('自动缓存清理已禁用，跳过启动清理');
      return;
    }

    _logger.info('开始执行启动缓存清理检查...');

    try {
      // 1. 检查时间过期的缓存
      await _cleanExpiredCache();

      // 2. 检查容量是否超限
      await _cleanIfOverCapacity();

      _logger.info('启动缓存清理检查完成');
    } catch (e) {
      _logger.error('启动缓存清理失败: $e');
    }
  }

  /// 清理过期缓存
  Future<void> _cleanExpiredCache() async {
    try {
      final expireTime =
          DateTime.now().subtract(Duration(days: _config.expireDays));

      // 清理过期的临时文件
      final tempDir = await getTemporaryDirectory();
      await _cleanExpiredFilesInDir(tempDir, expireTime);

      _logger.info('过期缓存清理完成');
    } catch (e) {
      _logger.warning('清理过期缓存失败: $e');
    }
  }

  /// 清理目录中过期的文件
  Future<void> _cleanExpiredFilesInDir(
      Directory dir, DateTime expireTime) async {
    try {
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(expireTime)) {
              await entity.delete();
            }
          } catch (_) {
            // 忽略无法访问的文件
          }
        } else if (entity is Directory) {
          await _cleanExpiredFilesInDir(entity, expireTime);
          // 如果目录为空则删除
          try {
            if (await entity.list().isEmpty) {
              await entity.delete();
            }
          } catch (_) {
            // 忽略
          }
        }
      }
    } catch (e) {
      _logger.warning('清理目录过期文件失败 ${dir.path}: $e');
    }
  }

  /// 检查并清理超容量的缓存
  Future<void> _cleanIfOverCapacity() async {
    try {
      final info = await getCacheInfo();
      final maxBytes = _config.maxSizeMB * 1024 * 1024;

      if (info.totalSize > maxBytes) {
        _logger.info(
            '缓存超出容量限制 (${info.formattedTotal}/${_config.maxSizeMB}MB)，开始清理...');
        await clearAllCache();
      }
    } catch (e) {
      _logger.warning('检查缓存容量失败: $e');
    }
  }

  /// 清理图片缓存
  Future<void> clearImageCache() async {
    try {
      // 清理 flutter_cache_manager 的缓存
      await DefaultCacheManager().emptyCache();

      // 手动清理缓存目录（备用）
      final tempDir = await getTemporaryDirectory();
      final imageCacheDir =
          Directory('${tempDir.path}/libCachedImageData');
      if (await imageCacheDir.exists()) {
        await imageCacheDir.delete(recursive: true);
      }

      _logger.info('图片缓存清理完成');
    } catch (e) {
      _logger.error('清理图片缓存失败: $e');
      rethrow;
    }
  }

  /// 清理临时文件缓存
  Future<void> clearTempCache() async {
    try {
      final tempDir = await getTemporaryDirectory();

      await for (final entity in tempDir.list()) {
        try {
          // 跳过图片缓存目录（由clearImageCache处理）
          if (entity.path.contains('libCachedImageData')) continue;

          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {
          // 忽略正在使用的文件
        }
      }

      _logger.info('临时文件缓存清理完成');
    } catch (e) {
      _logger.error('清理临时文件缓存失败: $e');
      rethrow;
    }
  }

  /// 清理其他缓存
  Future<void> clearOtherCache() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      await for (final entity in cacheDir.list()) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {
          // 忽略正在使用的文件
        }
      }

      _logger.info('其他缓存清理完成');
    } catch (e) {
      _logger.error('清理其他缓存失败: $e');
      rethrow;
    }
  }

  /// 清理所有缓存
  Future<void> clearAllCache() async {
    _logger.info('开始清理所有缓存...');

    try {
      await clearImageCache();
    } catch (_) {}

    try {
      await clearTempCache();
    } catch (_) {}

    try {
      await clearOtherCache();
    } catch (_) {}

    _logger.info('所有缓存清理完成');
  }
}
