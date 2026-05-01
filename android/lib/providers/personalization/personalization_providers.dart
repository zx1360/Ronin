import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

/// 个性化服务单例Provider
final personalizationServiceProvider = Provider<PersonalizationService>((ref) {
  return PersonalizationService();
});

/// 当前设置状态Provider
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  final service = ref.watch(personalizationServiceProvider);
  return AppSettingsNotifier(service);
});

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final PersonalizationService _service;

  AppSettingsNotifier(this._service) : super(_service.getSettings());

  /// 刷新设置
  void refresh() {
    state = _service.getSettings();
  }

  /// 添加背景图片
  Future<bool> addBackgroundImage(List<int> bytes, String fileName) async {
    final result = await _service.addBackgroundImage(bytes, fileName);
    if (result) refresh();
    return result;
  }

  /// 删除背景图片
  Future<bool> removeBackgroundImage(String path) async {
    final result = await _service.removeBackgroundImage(path);
    if (result) refresh();
    return result;
  }

  /// 添加侧边栏图片
  Future<bool> addSidebarImage(List<int> bytes, String fileName) async {
    final result = await _service.addSidebarImage(bytes, fileName);
    if (result) refresh();
    return result;
  }

  /// 删除侧边栏图片
  Future<bool> removeSidebarImage(String path) async {
    final result = await _service.removeSidebarImage(path);
    if (result) refresh();
    return result;
  }

  /// 添加座右铭
  Future<void> addMotto(String motto) async {
    await _service.addMotto(motto);
    refresh();
  }

  /// 更新座右铭
  Future<void> updateMotto(int index, String motto) async {
    await _service.updateMotto(index, motto);
    refresh();
  }

  /// 删除座右铭
  Future<void> removeMotto(int index) async {
    await _service.removeMotto(index);
    refresh();
  }

  /// 更新昵称
  Future<void> updateNickname(String nickname) async {
    await _service.updateNickname(nickname);
    refresh();
  }

  /// 更新签名
  Future<void> updateSignature(String signature) async {
    await _service.updateSignature(signature);
    refresh();
  }

  /// 更新头像
  Future<bool> updateAvatar(List<int> bytes, String fileName) async {
    final result = await _service.updateAvatar(bytes, fileName);
    if (result) refresh();
    return result;
  }

  /// 清除头像
  Future<void> clearAvatar() async {
    await _service.clearAvatar();
    refresh();
  }
}

/// 背景图片文件列表Provider
final backgroundImagesProvider = FutureProvider<List<File>>((ref) async {
  final service = ref.watch(personalizationServiceProvider);
  // 监听设置变化以自动刷新
  ref.watch(appSettingsProvider);
  return service.getImageFiles(PersonalizationImageType.background);
});

/// 侧边栏图片文件列表Provider
final sidebarImagesProvider = FutureProvider<List<File>>((ref) async {
  final service = ref.watch(personalizationServiceProvider);
  ref.watch(appSettingsProvider);
  return service.getImageFiles(PersonalizationImageType.sidebar);
});

/// 当前选中的随机背景图路径
final randomBackgroundProvider = Provider<String?>((ref) {
  final service = ref.watch(personalizationServiceProvider);
  return service.getRandomBackgroundImage();
});

/// 当前选中的随机侧边栏图路径
final randomSidebarProvider = Provider<String?>((ref) {
  final service = ref.watch(personalizationServiceProvider);
  return service.getRandomSidebarImage();
});

/// 当前选中的随机座右铭
final randomMottoProvider = Provider<String>((ref) {
  final service = ref.watch(personalizationServiceProvider);
  return service.getRandomMotto();
});
