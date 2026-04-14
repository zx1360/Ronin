import 'package:northstar/domain/ops/models/arg_preset.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';

String? extractModeFromPreset(ArgPreset preset) {
  for (var i = 0; i < preset.args.length - 1; i++) {
    if (preset.args[i] == '-mode') {
      return preset.args[i + 1].trim().toLowerCase();
    }
  }
  return null;
}

bool requiresDangerConfirmation(TaskProfile task, ArgPreset preset) {
  final mode = extractModeFromPreset(preset);

  if (task.type == TaskType.gallery && mode == 'execute') {
    return true;
  }

  if (task.type == TaskType.comicIndexer &&
      (mode == 'full-reindex' || mode == 'refresh')) {
    return true;
  }

  return false;
}

String buildDangerPhrase(TaskProfile task, ArgPreset preset) {
  return 'CONFIRM ${task.name} ${preset.name}';
}

bool requiresFfmpegCheck(TaskProfile task, ArgPreset preset) {
  final mode = extractModeFromPreset(preset);
  if (task.type == TaskType.gallery &&
      (mode == 'ingest' || mode == 'execute')) {
    return true;
  }
  return false;
}
