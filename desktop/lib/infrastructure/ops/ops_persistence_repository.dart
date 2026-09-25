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

  // 启动预载结果：首次读取时才真正开始，因此 bootstrap() 必须先 await
  // ensureLoaded()，provider 才能在 build 里同步拿到持久化配置——否则首个请求
  // 会带着默认值发出（必然连错端口）。
  late final Future<void> _preload = _preloadAll();
  OpsSettings? _settingsCache;
  List<TaskProfile>? _tasksCache;

  /// 等待预载完成（供启动流程使用；provider 侧直接读取同步快照）。
  Future<void> ensureLoaded() => _preload;

  /// 已持久化的配置；未预载/无缓存时返回 null。
  OpsSettings? get settings => _settingsCache;

  /// 已持久化的任务档案；未预载/无缓存时返回 null。
  List<TaskProfile>? get taskProfiles => _tasksCache;

  Future<void> _preloadAll() async {
    try {
      _settingsCache = await _loadSettingsFromDisk();
      _tasksCache = await _loadTaskProfilesFromDisk();
    } catch (_) {
      // 预载失败时保持 null，由调用方回退到默认值。
    }
  }

  Future<OpsSettings?> _loadSettingsFromDisk() async {
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

  /// 保存配置；返回是否至少写入成功一处（主文件或旧版 SharedPreferences）。
  Future<bool> saveSettings(OpsSettings settings) async {
    _settingsCache = settings;
    final payload = jsonEncode(settings.toJson());
    if (await _writePrimaryFile(_settingsFileName, payload)) {
      return true;
    }
    return _writeLegacyValue(_legacySettingsKey, payload);
  }

  Future<List<TaskProfile>?> _loadTaskProfilesFromDisk() async {
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

  /// 保存任务档案；返回是否至少写入成功一处（主文件或旧版 SharedPreferences）。
  Future<bool> saveTaskProfiles(List<TaskProfile> tasks) async {
    _tasksCache = tasks;
    final payload = tasks.map((item) => item.toJson()).toList(growable: false);
    final encoded = jsonEncode(payload);
    if (await _writePrimaryFile(_tasksFileName, encoded)) {
      return true;
    }
    return _writeLegacyValue(_legacyTasksKey, encoded);
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
    final directory = Directory(storageDirectoryPath());
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  /// 本地配置目录（base/northstar_data/ops）：设置页展示与实际写入共用同一路径，
  /// 避免两处各写一份推导逻辑。
  static String storageDirectoryPath() {
    return path.join(_resolveBaseStoragePath(), _storageFolder, _opsSubFolder);
  }

  static String _resolveBaseStoragePath() {
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

  Future<bool> _writeLegacyValue(String key, String value) async {
    try {
      final prefs = await PrefsService.prefs;
      return await prefs.setString(key, value);
    } catch (_) {
      // no-op: fallback write failure should not break runtime.
      return false;
    }
  }
}
