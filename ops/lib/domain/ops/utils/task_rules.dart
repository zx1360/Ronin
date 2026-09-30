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

bool requiresFfmpegCheck(TaskProfile task, ArgPreset preset) {
  final mode = extractModeFromPreset(preset);
  if (task.type == TaskType.gallery &&
      (mode == 'ingest' || mode == 'execute')) {
    return true;
  }
  return false;
}
