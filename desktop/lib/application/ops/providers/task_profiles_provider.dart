import 'dart:convert';

import 'dart:async';

import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/domain/ops/models/arg_preset.dart';
import 'package:northstar/domain/ops/models/default_task_templates.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_profiles_provider.g.dart';

@Riverpod(keepAlive: true)
class TaskProfilesController extends _$TaskProfilesController {
  static const Set<String> _deprecatedBuiltinTaskIds = <String>{
    'gallery-util-1',
    'gallery-util-2',
  };

  @override
  List<TaskProfile> build() {
    final defaults = buildDefaultTaskTemplates();

    Future<void>(() async {
      final repository = ref.read(opsPersistenceRepositoryProvider);
      final cached = await repository.loadTaskProfiles();
      if (cached == null || cached.isEmpty) {
        state = defaults;
        await repository.saveTaskProfiles(defaults);
        return;
      }

      final migrated = _migrateCachedTaskProfiles(
        cached: cached,
        defaults: defaults,
      );

      state = migrated;
      if (!_taskListsSemanticallyEqual(cached, migrated)) {
        await repository.saveTaskProfiles(migrated);
      }
    });

    return defaults;
  }

  List<TaskProfile> _migrateCachedTaskProfiles({
    required List<TaskProfile> cached,
    required List<TaskProfile> defaults,
  }) {
    final filtered = cached
        .where((task) => !_deprecatedBuiltinTaskIds.contains(task.id))
        .toList(growable: false);

    if (filtered.isEmpty) {
      return defaults;
    }

    final defaultsById = <String, TaskProfile>{
      for (final template in defaults) template.id: template,
    };

    return filtered
        .map((task) {
          if (task.id != 'gallery-main') {
            return task;
          }

          final galleryTemplate = defaultsById[task.id];
          if (galleryTemplate == null) {
            return task;
          }

          return _mergeGalleryProfile(task, galleryTemplate);
        })
        .toList(growable: false);
  }

  TaskProfile _mergeGalleryProfile(TaskProfile cached, TaskProfile template) {
    final hasRefreshPreset = cached.presets.any(_isGalleryRefreshPreset);
    if (hasRefreshPreset) {
      return cached;
    }

    final refreshPreset = template.presets.firstWhere(
      (preset) => preset.id == 'refresh',
      orElse: () => template.presets.first,
    );

    final mergedPresets = <ArgPreset>[...cached.presets, refreshPreset];
    final selectedPresetId = cached.selectedPresetId.trim().isEmpty
        ? mergedPresets.first.id
        : cached.selectedPresetId;

    return cached.copyWith(
      presets: mergedPresets,
      selectedPresetId: selectedPresetId,
    );
  }

  bool _isGalleryRefreshPreset(ArgPreset preset) {
    if (preset.id == 'refresh') {
      return true;
    }

    for (var i = 0; i < preset.args.length - 1; i++) {
      if (preset.args[i] == '-mode' &&
          preset.args[i + 1].trim().toLowerCase() == 'refresh') {
        return true;
      }
    }

    return false;
  }

  bool _taskListsSemanticallyEqual(
    List<TaskProfile> left,
    List<TaskProfile> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    final leftJson = left.map((item) => item.toJson()).toList(growable: false);
    final rightJson = right
        .map((item) => item.toJson())
        .toList(growable: false);

    return jsonEncode(leftJson) == jsonEncode(rightJson);
  }

  Future<void> upsertTask(TaskProfile profile) async {
    final next = <TaskProfile>[];
    var replaced = false;

    for (final item in state) {
      if (item.id == profile.id) {
        next.add(profile);
        replaced = true;
      } else {
        next.add(item);
      }
    }

    if (!replaced) {
      next.add(profile);
    }

    state = next;
    await _save();
  }

  Future<void> removeTask(String taskId) async {
    state = state.where((item) => item.id != taskId).toList(growable: false);
    await _save();
  }

  Future<void> setSelectedPreset({
    required String taskId,
    required String presetId,
  }) async {
    final next = state
        .map(
          (task) => task.id == taskId
              ? task.copyWith(selectedPresetId: presetId)
              : task,
        )
        .toList(growable: false);

    state = next;
    await _save();
  }

  Future<void> replaceAll(List<TaskProfile> tasks) async {
    state = tasks;
    await _save();
  }

  Future<void> _save() async {
    final repository = ref.read(opsPersistenceRepositoryProvider);
    await repository.saveTaskProfiles(state);
  }
}
