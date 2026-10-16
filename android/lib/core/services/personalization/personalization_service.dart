import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

enum PersonalizationImageType { background, sidebar, avatar }

class PersonalizationService {
  static final PersonalizationService _instance = PersonalizationService._();
  PersonalizationService._();
  factory PersonalizationService() => _instance;

  static const _defaultMotto = '理想如星\n虽不能及,吾心往之';
  final Random _random = Random();
  Future<void> _pending = Future.value();

  AppSettings getSettings() {
    final raw = PrefsService().prefs.getString('preferences');
    if (raw == null || raw.isEmpty) return AppSettings.defaultValue();
    try {
      return AppSettings.fromJson(jsonDecode(raw));
    } catch (error) {
      AppLogger().error('解析偏好设置失败: $error');
      return AppSettings.defaultValue();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _write(
    AppSettings settings, {
    Future<void> Function()? onRollback,
  }) async {
    final prefs = PrefsService().prefs;
    final previous = prefs.getString('preferences');
    try {
      if (!await prefs.setString(
        'preferences',
        jsonEncode(settings.toJson()),
      )) {
        throw StateError('偏好设置保存失败');
      }
    } catch (error) {
      final restored = previous == null
          ? await prefs.remove('preferences')
          : await prefs.setString('preferences', previous);
      if (!restored) throw StateError('偏好保存失败且回退失败: $error');
      await onRollback?.call();
      rethrow;
    }
  }

  Future<void> _update(AppSettings Function(AppSettings) change) =>
      _enqueue(() => _write(change(getSettings())));

  Future<void> _deleteUnused(String? key) async {
    if (key == null) return;
    try {
      await IoService.deleteUserFile(key);
    } catch (error) {
      AppLogger().warning('清理未使用的个性化图片失败: $error');
    }
  }

  Future<bool> _saveImage(
    PersonalizationImageType type,
    List<int> bytes,
    String fileName,
  ) => _enqueue(() async {
    String? key;
    try {
      if (bytes.isEmpty) throw const FormatException('图片文件为空');
      final extension = path.extension(fileName).toLowerCase();
      key =
          'preferences/${type.name}/${const Uuid().v4()}${extension.isEmpty ? '.jpg' : extension}';
      await IoService.writeAtomically(await IoService.userFile(key), bytes);
      final settings = getSettings();
      final updated = switch (type) {
        PersonalizationImageType.background => settings.copyWith(
          backgroundImages: [...settings.backgroundImages, key],
        ),
        PersonalizationImageType.sidebar => settings.copyWith(
          sidebarImages: [...settings.sidebarImages, key],
        ),
        PersonalizationImageType.avatar => settings.copyWith(avatarPath: key),
      };
      await _write(updated, onRollback: () => _deleteUnused(key));
      if (type == PersonalizationImageType.avatar) {
        await _deleteUnused(settings.avatarPath);
      }
      return true;
    } catch (error) {
      AppLogger().error('保存个性化图片失败: $error');
      return false;
    }
  });

  Future<bool> _removeImage(PersonalizationImageType type, String key) =>
      _enqueue(() async {
        try {
          final settings = getSettings();
          final updated = switch (type) {
            PersonalizationImageType.background => settings.copyWith(
              backgroundImages: settings.backgroundImages
                  .where((item) => item != key)
                  .toList(),
            ),
            PersonalizationImageType.sidebar => settings.copyWith(
              sidebarImages: settings.sidebarImages
                  .where((item) => item != key)
                  .toList(),
            ),
            PersonalizationImageType.avatar => settings.copyWith(
              clearAvatar: true,
            ),
          };
          await _write(updated);
          await _deleteUnused(key);
          return true;
        } catch (error) {
          AppLogger().error('删除个性化图片失败: $error');
          return false;
        }
      });

  Future<List<File>> getImageFiles(PersonalizationImageType type) async {
    final settings = getSettings();
    final keys = switch (type) {
      PersonalizationImageType.background => settings.backgroundImages,
      PersonalizationImageType.sidebar => settings.sidebarImages,
      PersonalizationImageType.avatar => [
        if (settings.avatarPath != null) settings.avatarPath!,
      ],
    };
    return (await Future.wait(
      keys.map(getImageFile),
    )).whereType<File>().toList();
  }

  Future<File?> getImageFile(String key) => IoService.getImageFile(key);

  String? _choose(List<String> items) =>
      items.isEmpty ? null : items[_random.nextInt(items.length)];

  String? getRandomBackgroundImage() => _choose(getSettings().backgroundImages);
  String? getRandomSidebarImage() => _choose(getSettings().sidebarImages);
  String getRandomMotto() => _choose(getSettings().mottos) ?? _defaultMotto;

  Future<bool> addBackgroundImage(List<int> bytes, String name) =>
      _saveImage(PersonalizationImageType.background, bytes, name);

  Future<bool> addSidebarImage(List<int> bytes, String name) =>
      _saveImage(PersonalizationImageType.sidebar, bytes, name);

  Future<bool> updateAvatar(List<int> bytes, String name) =>
      _saveImage(PersonalizationImageType.avatar, bytes, name);

  Future<bool> removeBackgroundImage(String key) =>
      _removeImage(PersonalizationImageType.background, key);

  Future<bool> removeSidebarImage(String key) =>
      _removeImage(PersonalizationImageType.sidebar, key);

  Future<void> clearAvatar() => _enqueue(() async {
    final settings = getSettings();
    await _write(settings.copyWith(clearAvatar: true));
    await _deleteUnused(settings.avatarPath);
  });

  Future<void> addMotto(String motto) => _update(
    (settings) => motto.trim().isEmpty
        ? settings
        : settings.copyWith(mottos: [...settings.mottos, motto.trim()]),
  );

  Future<void> updateMotto(int index, String motto) => _update((settings) {
    if (index < 0 || index >= settings.mottos.length || motto.trim().isEmpty) {
      return settings;
    }
    final mottos = List<String>.of(settings.mottos);
    mottos[index] = motto.trim();
    return settings.copyWith(mottos: mottos);
  });

  Future<void> removeMotto(int index) => _update((settings) {
    if (index < 0 || index >= settings.mottos.length) return settings;
    final mottos = List<String>.of(settings.mottos)..removeAt(index);
    return settings.copyWith(mottos: mottos.isEmpty ? [_defaultMotto] : mottos);
  });

  Future<void> updateNickname(String name) => _update(
    (settings) =>
        settings.copyWith(nickname: name.trim().isEmpty ? '用户昵称' : name.trim()),
  );

  Future<void> updateSignature(String signature) => _update(
    (settings) => settings.copyWith(
      signature: signature.trim().isEmpty ? '这个人很懒，什么都没写~' : signature.trim(),
    ),
  );
}
