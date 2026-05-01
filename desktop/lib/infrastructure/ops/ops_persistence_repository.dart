import 'dart:convert';
import 'dart:io';

import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/services/storage/prefs_service.dart';
import 'package:path/path.dart' as path;

class OpsPersistenceRepository {
  static const _legacySettingsKey = 'ops.settings.v1';
  static const _legacyTasksKey = 'ops.tasks.v1';
  static const _storageFolder = 'northstar_data';
  static const _opsSubFolder = 'ops';
  static const _settingsFileName = 'ops.settings.v1.json';
  static const _tasksFileName = 'ops.tasks.v1.json';

  Future<OpsSettings?> loadSettings() async {
    final localRaw = await _readPrimaryFile(_settingsFileName);
    final localJson = _decodeJsonMap(localRaw);
    if (localJson != null) {
      return OpsSettings.fromJson(localJson);
    }

    final legacyRaw = await _readLegacyValue(_legacySettingsKey);
    final legacyJson = _decodeJsonMap(legacyRaw);
    if (legacyJson == null) {
      return null;
    }

    final settings = OpsSettings.fromJson(legacyJson);
    await saveSettings(settings);
    return settings;
  }

  Future<void> saveSettings(OpsSettings settings) async {
    final payload = jsonEncode(settings.toJson());
    final savedToPrimary = await _writePrimaryFile(_settingsFileName, payload);
    if (!savedToPrimary) {
      await _writeLegacyValue(_legacySettingsKey, payload);
    }
  }

  Future<List<TaskProfile>?> loadTaskProfiles() async {
    final localRaw = await _readPrimaryFile(_tasksFileName);
    final localJson = _decodeJsonList(localRaw);
    if (localJson != null) {
      return _decodeTasks(localJson);
    }

    final legacyRaw = await _readLegacyValue(_legacyTasksKey);
    final legacyJson = _decodeJsonList(legacyRaw);
    if (legacyJson == null) {
      return null;
    }

    final tasks = _decodeTasks(legacyJson);
    await saveTaskProfiles(tasks);
    return tasks;
  }

  Future<void> saveTaskProfiles(List<TaskProfile> tasks) async {
    final payload = tasks.map((item) => item.toJson()).toList(growable: false);
    final encoded = jsonEncode(payload);
    final savedToPrimary = await _writePrimaryFile(_tasksFileName, encoded);
    if (!savedToPrimary) {
      await _writeLegacyValue(_legacyTasksKey, encoded);
    }
  }

  List<TaskProfile> _decodeTasks(List<dynamic> entries) {
    final items = <TaskProfile>[];
    for (final entry in entries) {
      if (entry is Map) {
        items.add(TaskProfile.fromJson(entry.cast<String, dynamic>()));
      }
    }
    return items;
  }

  Map<String, dynamic>? _decodeJsonMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) {
        return parsed.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  List<dynamic>? _decodeJsonList(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) {
        return parsed;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<String?> _readPrimaryFile(String fileName) async {
    try {
      final directory = await _storageDirectory();
      final file = File(path.join(directory.path, fileName));
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _writePrimaryFile(String fileName, String content) async {
    try {
      final directory = await _storageDirectory();
      final file = File(path.join(directory.path, fileName));
      await file.writeAsString(content, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _storageDirectory() async {
    final basePath = _resolveBaseStoragePath();
    final targetPath = path.join(basePath, _storageFolder, _opsSubFolder);
    final directory = Directory(targetPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _resolveBaseStoragePath() {
    final executablePath = Platform.resolvedExecutable;
    final executableName = path.basename(executablePath).toLowerCase();

    // flutter_tester/dart 运行时使用当前目录，避免写到 SDK 缓存目录。
    if (executableName == 'flutter_tester.exe' ||
        executableName == 'dart.exe') {
      return Directory.current.path;
    }

    return File(executablePath).parent.path;
  }

  Future<String?> _readLegacyValue(String key) async {
    try {
      final prefs = await PrefsService.prefs;
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLegacyValue(String key, String value) async {
    try {
      final prefs = await PrefsService.prefs;
      await prefs.setString(key, value);
    } catch (_) {
      // no-op: fallback write failure should not break runtime.
    }
  }
}
