import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/core/services/debug/logging_service.dart';

/// 个性化图片类型
enum PersonalizationImageType {
  background, // 背景图（Splash/Home共用）
  sidebar,    // 侧边栏背景图
  avatar,     // 用户头像
}

/// 个性化配置服务
/// 管理背景图片、侧边栏图片、座右铭和用户信息
class PersonalizationService {
  // 单例模式
  static final PersonalizationService _instance = PersonalizationService._();
  PersonalizationService._();
  factory PersonalizationService() => _instance;

  final PrefsService _prefsService = PrefsService();
  final Random _random = Random();

  // 目录路径常量
  static const String _preferencesDir = 'preferences';
  static const String _backgroundDir = 'background';
  static const String _sidebarDir = 'sidebar';
  static const String _avatarDir = 'avatar';

  /// 获取图片类型对应的目录名
  String _getDirName(PersonalizationImageType type) {
    switch (type) {
      case PersonalizationImageType.background:
        return _backgroundDir;
      case PersonalizationImageType.sidebar:
        return _sidebarDir;
      case PersonalizationImageType.avatar:
        return _avatarDir;
    }
  }

  /// 获取当前偏好设置
  AppSettings getSettings() {
    final prefsString = _prefsService.prefs.getString('preferences');
    if (prefsString == null || prefsString.isEmpty) {
      return AppSettings.defaultValue();
    }
    try {
      return AppSettings.fromJson(jsonDecode(prefsString));
    } catch (e) {
      AppLogger().error('解析偏好设置失败: $e');
      return AppSettings.defaultValue();
    }
  }

  /// 保存偏好设置
  Future<void> saveSettings(AppSettings settings) async {
    await _prefsService.prefs.setString(
      'preferences',
      jsonEncode(settings.toJson()),
    );
  }

  /// 确保图片目录存在
  Future<Directory> _ensureImageDir(PersonalizationImageType type) async {
    final dirName = _getDirName(type);
    return IoService.ensureDirExists('$_preferencesDir/$dirName');
  }

  /// 保存图片到指定目录
  /// 返回保存后的相对路径
  Future<String?> saveImage({
    required PersonalizationImageType type,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final dirName = _getDirName(type);
      final relativePath = '$_preferencesDir/$dirName/$fileName';
      await IoService.saveImageToExternalStorage(
        relativePath: relativePath,
        bytes: bytes,
      );
      return relativePath;
    } catch (e) {
      AppLogger().error('保存图片失败: $e');
      return null;
    }
  }

  /// 删除图片
  Future<bool> deleteImage(String relativePath) async {
    try {
      final externalDir = await IoService.externalStorageDir;
      final file = File(path.join(externalDir.path, relativePath));
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger().error('删除图片失败: $e');
      return false;
    }
  }

  /// 获取某类型图片的所有文件
  Future<List<File>> getImageFiles(PersonalizationImageType type) async {
    try {
      final dir = await _ensureImageDir(type);
      final entities = await dir.list().toList();
      return entities
          .whereType<File>()
          .where((f) => _isImageFile(f.path))
          .toList();
    } catch (e) {
      AppLogger().error('获取图片列表失败: $e');
      return [];
    }
  }

  /// 判断是否为图片文件
  bool _isImageFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext);
  }

  /// 获取图片文件（通过相对路径）
  Future<File?> getImageFile(String relativePath) async {
    return IoService.getImageFile(relativePath);
  }

  /// 随机选择一张背景图片路径
  /// 如果没有自定义图片，返回null
  String? getRandomBackgroundImage() {
    final settings = getSettings();
    if (settings.backgroundImages.isEmpty) {
      return null;
    }
    final index = _random.nextInt(settings.backgroundImages.length);
    return settings.backgroundImages[index];
  }

  /// 随机选择一张侧边栏图片路径
  /// 如果没有自定义图片，返回null
  String? getRandomSidebarImage() {
    final settings = getSettings();
    if (settings.sidebarImages.isEmpty) {
      return null;
    }
    final index = _random.nextInt(settings.sidebarImages.length);
    return settings.sidebarImages[index];
  }

  /// 随机选择一条座右铭
  String getRandomMotto() {
    final settings = getSettings();
    if (settings.mottos.isEmpty) {
      return "理想如星\n虽不能及,吾心往之";
    }
    final index = _random.nextInt(settings.mottos.length);
    return settings.mottos[index];
  }

  // ============ 背景图片管理 ============

  /// 添加背景图片
  Future<bool> addBackgroundImage(List<int> bytes, String fileName) async {
    final relativePath = await saveImage(
      type: PersonalizationImageType.background,
      bytes: bytes,
      fileName: fileName,
    );
    if (relativePath != null) {
      final settings = getSettings();
      final newList = [...settings.backgroundImages, relativePath];
      await saveSettings(settings.copyWith(backgroundImages: newList));
      return true;
    }
    return false;
  }

  /// 删除背景图片
  Future<bool> removeBackgroundImage(String relativePath) async {
    final deleted = await deleteImage(relativePath);
    if (deleted) {
      final settings = getSettings();
      final newList = settings.backgroundImages
          .where((p) => p != relativePath)
          .toList();
      await saveSettings(settings.copyWith(backgroundImages: newList));
    }
    return deleted;
  }

  // ============ 侧边栏图片管理 ============

  /// 添加侧边栏图片
  Future<bool> addSidebarImage(List<int> bytes, String fileName) async {
    final relativePath = await saveImage(
      type: PersonalizationImageType.sidebar,
      bytes: bytes,
      fileName: fileName,
    );
    if (relativePath != null) {
      final settings = getSettings();
      final newList = [...settings.sidebarImages, relativePath];
      await saveSettings(settings.copyWith(sidebarImages: newList));
      return true;
    }
    return false;
  }

  /// 删除侧边栏图片
  Future<bool> removeSidebarImage(String relativePath) async {
    final deleted = await deleteImage(relativePath);
    if (deleted) {
      final settings = getSettings();
      final newList = settings.sidebarImages
          .where((p) => p != relativePath)
          .toList();
      await saveSettings(settings.copyWith(sidebarImages: newList));
    }
    return deleted;
  }

  // ============ 座右铭管理 ============

  /// 添加座右铭
  Future<void> addMotto(String motto) async {
    if (motto.trim().isEmpty) return;
    final settings = getSettings();
    final newList = [...settings.mottos, motto.trim()];
    await saveSettings(settings.copyWith(mottos: newList));
  }

  /// 更新座右铭
  Future<void> updateMotto(int index, String motto) async {
    final settings = getSettings();
    if (index < 0 || index >= settings.mottos.length) return;
    final newList = List<String>.from(settings.mottos);
    newList[index] = motto.trim();
    await saveSettings(settings.copyWith(mottos: newList));
  }

  /// 删除座右铭
  Future<void> removeMotto(int index) async {
    final settings = getSettings();
    if (index < 0 || index >= settings.mottos.length) return;
    final newList = List<String>.from(settings.mottos);
    newList.removeAt(index);
    // 确保至少保留一条座右铭
    if (newList.isEmpty) {
      newList.add("理想如星\n虽不能及,吾心往之");
    }
    await saveSettings(settings.copyWith(mottos: newList));
  }

  // ============ 用户信息管理 ============

  /// 更新昵称
  Future<void> updateNickname(String nickname) async {
    final settings = getSettings();
    await saveSettings(settings.copyWith(
      nickname: nickname.trim().isEmpty ? "用户昵称" : nickname.trim(),
    ));
  }

  /// 更新签名
  Future<void> updateSignature(String signature) async {
    final settings = getSettings();
    await saveSettings(settings.copyWith(
      signature: signature.trim().isEmpty ? "这个人很懒，什么都没写~" : signature.trim(),
    ));
  }

  /// 更新头像
  /// 会自动删除旧头像
  Future<bool> updateAvatar(List<int> bytes, String fileName) async {
    final settings = getSettings();
    
    // 删除旧头像
    if (settings.avatarPath != null) {
      await deleteImage(settings.avatarPath!);
    }
    
    // 确保目录存在
    await _ensureImageDir(PersonalizationImageType.avatar);
    
    // 保存新头像
    final relativePath = await saveImage(
      type: PersonalizationImageType.avatar,
      bytes: bytes,
      fileName: fileName,
    );
    
    if (relativePath != null) {
      await saveSettings(settings.copyWith(avatarPath: relativePath));
      return true;
    }
    return false;
  }

  /// 清除头像（恢复默认）
  Future<void> clearAvatar() async {
    final settings = getSettings();
    if (settings.avatarPath != null) {
      await deleteImage(settings.avatarPath!);
      await saveSettings(settings.copyWith(clearAvatar: true));
    }
  }
}
