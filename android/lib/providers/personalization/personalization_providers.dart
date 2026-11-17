import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  final _service = PersonalizationService();

  @override
  AppSettings build() => _service.getSettings();

  void refresh() {
    if (ref.mounted) state = _service.getSettings();
  }

  Future<bool> addBackgroundImage(List<int> bytes, String fileName) async {
    final result = await _service.addBackgroundImage(bytes, fileName);
    if (result) refresh();
    return result;
  }

  Future<bool> removeBackgroundImage(String path) async {
    final result = await _service.removeBackgroundImage(path);
    if (result) refresh();
    return result;
  }

  Future<bool> addSidebarImage(List<int> bytes, String fileName) async {
    final result = await _service.addSidebarImage(bytes, fileName);
    if (result) refresh();
    return result;
  }

  Future<bool> removeSidebarImage(String path) async {
    final result = await _service.removeSidebarImage(path);
    if (result) refresh();
    return result;
  }

  Future<void> addMotto(String motto) async {
    await _service.addMotto(motto);
    refresh();
  }

  Future<void> updateMotto(int index, String motto) async {
    await _service.updateMotto(index, motto);
    refresh();
  }

  Future<void> removeMotto(int index) async {
    await _service.removeMotto(index);
    refresh();
  }

  Future<void> updateNickname(String nickname) async {
    await _service.updateNickname(nickname);
    refresh();
  }

  Future<void> updateSignature(String signature) async {
    await _service.updateSignature(signature);
    refresh();
  }

  Future<bool> updateAvatar(List<int> bytes, String fileName) async {
    final result = await _service.updateAvatar(bytes, fileName);
    if (result) refresh();
    return result;
  }

  Future<void> clearAvatar() async {
    await _service.clearAvatar();
    refresh();
  }
}

final backgroundImagesProvider = FutureProvider.autoDispose<List<File>>((ref) {
  final keys = ref.watch(
    appSettingsProvider.select((settings) => settings.backgroundImages),
  );
  return _imageFiles(keys);
});

final sidebarImagesProvider = FutureProvider.autoDispose<List<File>>((ref) {
  final keys = ref.watch(
    appSettingsProvider.select((settings) => settings.sidebarImages),
  );
  return _imageFiles(keys);
});

Future<List<File>> _imageFiles(List<String> keys) async => (await Future.wait(
  keys.map(IoService.getImageFile),
)).whereType<File>().toList();
