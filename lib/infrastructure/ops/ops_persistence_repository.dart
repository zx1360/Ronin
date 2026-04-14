import 'dart:convert';

import 'package:northstar/domain/ops/models/ops_settings.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/services/storage/prefs_service.dart';

class OpsPersistenceRepository {
  static const _settingsKey = 'ops.settings.v1';
  static const _tasksKey = 'ops.tasks.v1';

  Future<OpsSettings?> loadSettings() async {
    final prefs = await PrefsService.prefs;
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final parsed = jsonDecode(raw);
    if (parsed is! Map) {
      return null;
    }

    return OpsSettings.fromJson(parsed.cast<String, dynamic>());
  }

  Future<void> saveSettings(OpsSettings settings) async {
    final prefs = await PrefsService.prefs;
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<TaskProfile>?> loadTaskProfiles() async {
    final prefs = await PrefsService.prefs;
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final parsed = jsonDecode(raw);
    if (parsed is! List) {
      return null;
    }

    final items = <TaskProfile>[];
    for (final entry in parsed) {
      if (entry is Map) {
        items.add(TaskProfile.fromJson(entry.cast<String, dynamic>()));
      }
    }
    return items;
  }

  Future<void> saveTaskProfiles(List<TaskProfile> tasks) async {
    final prefs = await PrefsService.prefs;
    final payload = tasks.map((item) => item.toJson()).toList(growable: false);
    await prefs.setString(_tasksKey, jsonEncode(payload));
  }
}
