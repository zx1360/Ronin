/// 缓存管理服务
///
/// 提供应用缓存的统一管理，包括：
/// - 缓存大小计算
/// - 自动清理（按时间/容量）
/// - 手动清理
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;

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

  const CacheInfo({this.imageCacheSize = 0, this.tempCacheSize = 0});

  /// 总缓存大小（字节）
  int get totalSize => imageCacheSize + tempCacheSize;

  /// 获取格式化的大小字符串
  String get formattedTotal => _formatSize(totalSize);
  String get formattedImageCache => _formatSize(imageCacheSize);
  String get formattedTempCache => _formatSize(tempCacheSize);

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class CacheService {
  static final CacheService _instance = CacheService._();
  CacheService._();
  factory CacheService() => _instance;

  static const temporaryNames = ['media_share', 'media_export'];
  static const temporaryRetention = Duration(days: 1);

  CacheConfig _config = const CacheConfig();
  CacheConfig get config => _config;

  Future<void> init() async {
    _config = CacheConfig.fromPrefs();
  }

  Future<void> updateConfig(CacheConfig value) async {
    if (value.expireDays <= 0 || value.maxSizeMB <= 0) {
      throw const FormatException('缓存期限和容量必须大于零');
    }
    await value.saveToPrefs();
    _config = value;
  }

  Future<CacheInfo> getCacheInfo() async => CacheInfo(
    imageCacheSize: await _directorySize(await _imageDirectory()),
    tempCacheSize: await _temporarySize(),
  );

  Future<Directory> _imageDirectory() async => Directory(
    path.join((await getTemporaryDirectory()).path, DefaultCacheManager.key),
  );

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var size = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          size += await entity.length();
        } on PathNotFoundException {
          continue;
        }
      }
    }
    return size;
  }

  Future<int> _temporarySize() async {
    final root = await getTemporaryDirectory();
    var size = 0;
    for (final name in temporaryNames) {
      final directory = Directory(path.join(root.path, name));
      size += await _directorySize(directory);
    }
    return size;
  }

  Future<void> performStartupCleanup() async {
    if (!_config.autoCleanEnabled) return;
    try {
      await _cleanTemporary(Duration(days: _config.expireDays));
      var imageSize = await _directorySize(await _imageDirectory());
      if (imageSize == 0) return;
      final manager = DefaultCacheManager();
      await manager.store.getCacheSize();
      final budget = math.max(
        0,
        _config.maxSizeMB * 1024 * 1024 - await _temporarySize(),
      );
      final cutoff = DateTime.now().subtract(
        Duration(days: _config.expireDays),
      );
      final entries = await manager.config.repo.getAllObjects();
      entries.sort(
        (first, second) => (first.touched ?? DateTime(1970)).compareTo(
          second.touched ?? DateTime(1970),
        ),
      );
      for (final entry in entries) {
        if (entry.touched?.isBefore(cutoff) != false || imageSize > budget) {
          final file = await manager.config.fileSystem.createFile(
            entry.relativePath,
          );
          final size = await file.exists() ? await file.length() : 0;
          await manager.removeFile(entry.key);
          if (await file.exists()) await file.delete();
          imageSize -= size;
        }
      }
    } catch (error) {
      AppLogger().warning('启动缓存清理失败: $error');
    }
  }

  Future<void> _cleanTemporary(Duration age) async {
    final root = await getTemporaryDirectory();
    final cutoff = DateTime.now().subtract(
      age < temporaryRetention ? temporaryRetention : age,
    );
    for (final name in temporaryNames) {
      final directory = Directory(path.join(root.path, name));
      if (!await directory.exists()) continue;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! Directory) continue;
        try {
          if ((await entry.stat()).modified.isBefore(cutoff)) {
            await entry.delete(recursive: true);
          }
        } on PathNotFoundException {
          continue;
        }
      }
    }
  }

  Future<void> clearImageCache() async {
    await DefaultCacheManager().emptyCache();
    final directory = await _imageDirectory();
    if (!await directory.exists()) return;
    await for (final entry in directory.list(followLinks: false)) {
      await entry.delete(recursive: entry is Directory);
    }
  }

  Future<void> clearTempCache() => _cleanTemporary(temporaryRetention);

  Future<void> clearAllCache() async {
    await clearImageCache();
    await clearTempCache();
  }
}
