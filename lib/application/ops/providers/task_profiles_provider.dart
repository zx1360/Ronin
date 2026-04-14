import 'dart:async';

import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/domain/ops/models/default_task_templates.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_profiles_provider.g.dart';

@Riverpod(keepAlive: true)
class TaskProfilesController extends _$TaskProfilesController {
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

      state = cached;
    });

    return defaults;
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
        .map((task) => task.id == taskId
            ? task.copyWith(selectedPresetId: presetId)
            : task)
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
