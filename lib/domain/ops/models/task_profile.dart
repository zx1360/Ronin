import 'package:northstar/domain/ops/models/arg_preset.dart';

enum TaskType { monarch, gallery, comicIndexer, custom }

class TaskProfile {
  final String id;
  final TaskType type;
  final String name;
  final String executablePath;
  final String workingDirectory;
  final List<ArgPreset> presets;
  final String selectedPresetId;
  final bool dangerousOperation;
  final bool hiddenByDefault;
  final bool supportsGracefulStop;

  const TaskProfile({
    required this.id,
    required this.type,
    required this.name,
    required this.executablePath,
    required this.workingDirectory,
    required this.presets,
    required this.selectedPresetId,
    required this.dangerousOperation,
    required this.hiddenByDefault,
    required this.supportsGracefulStop,
  });

  ArgPreset get selectedPreset {
    if (presets.isEmpty) {
      return const ArgPreset(id: 'empty', name: '默认', args: <String>[]);
    }
    for (final preset in presets) {
      if (preset.id == selectedPresetId) {
        return preset;
      }
    }
    return presets.first;
  }

  TaskProfile copyWith({
    String? id,
    TaskType? type,
    String? name,
    String? executablePath,
    String? workingDirectory,
    List<ArgPreset>? presets,
    String? selectedPresetId,
    bool? dangerousOperation,
    bool? hiddenByDefault,
    bool? supportsGracefulStop,
  }) {
    return TaskProfile(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      presets: presets ?? this.presets,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      dangerousOperation: dangerousOperation ?? this.dangerousOperation,
      hiddenByDefault: hiddenByDefault ?? this.hiddenByDefault,
      supportsGracefulStop: supportsGracefulStop ?? this.supportsGracefulStop,
    );
  }

  factory TaskProfile.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? TaskType.custom.name).toString();
    final type = TaskType.values.firstWhere(
      (item) => item.name == rawType,
      orElse: () => TaskType.custom,
    );

    final presets = ((json['presets'] as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => ArgPreset.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);

    final fallbackPresetId = presets.isEmpty ? '' : presets.first.id;

    return TaskProfile(
      id: (json['id'] ?? '').toString(),
      type: type,
      name: (json['name'] ?? '').toString(),
      executablePath: (json['executablePath'] ?? '').toString(),
      workingDirectory: (json['workingDirectory'] ?? '').toString(),
      presets: presets,
      selectedPresetId: (json['selectedPresetId'] ?? fallbackPresetId)
          .toString(),
      dangerousOperation: json['dangerousOperation'] == true,
      hiddenByDefault: json['hiddenByDefault'] == true,
      supportsGracefulStop: json['supportsGracefulStop'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'executablePath': executablePath,
      'workingDirectory': workingDirectory,
      'presets': presets.map((item) => item.toJson()).toList(growable: false),
      'selectedPresetId': selectedPresetId,
      'dangerousOperation': dangerousOperation,
      'hiddenByDefault': hiddenByDefault,
      'supportsGracefulStop': supportsGracefulStop,
    };
  }
}
