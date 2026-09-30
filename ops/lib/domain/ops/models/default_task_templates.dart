import 'package:northstar/domain/ops/models/arg_preset.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';

List<TaskProfile> buildDefaultTaskTemplates() {
  return const <TaskProfile>[
    TaskProfile(
      id: 'monarch-https',
      type: TaskType.monarch,
      name: 'Monarch HTTPS',
      executablePath: '',
      presets: <ArgPreset>[
        ArgPreset(id: 'https', name: 'Default', args: <String>[]),
      ],
      selectedPresetId: 'https',
      dangerousOperation: false,
      hiddenByDefault: false,
      supportsGracefulStop: true,
    ),
    TaskProfile(
      id: 'monarch-local',
      type: TaskType.monarch,
      name: 'Monarch Local',
      executablePath: '',
      presets: <ArgPreset>[
        ArgPreset(id: 'local', name: 'Local', args: <String>['-mode', 'local']),
      ],
      selectedPresetId: 'local',
      dangerousOperation: false,
      hiddenByDefault: false,
      supportsGracefulStop: true,
    ),
    TaskProfile(
      id: 'gallery-main',
      type: TaskType.gallery,
      name: 'Gallery',
      executablePath: '',
      presets: <ArgPreset>[
        ArgPreset(
          id: 'ingest',
          name: 'Gallery Ingest',
          args: <String>[
            '-mode',
            'ingest',
            '-gallery-root',
            '<请配置Gallery目录路径>',
            '-concurrency',
            '10',
            '-batch',
            '160',
          ],
        ),
        ArgPreset(
          id: 'execute',
          name: 'Gallery Execute',
          args: <String>[
            '-mode',
            'execute',
            '-gallery-root',
            '<请配置Gallery目录路径>',
            '-concurrency',
            '10',
            '-batch',
            '160',
          ],
        ),
        ArgPreset(
          id: 'refresh',
          name: 'Gallery Refresh',
          args: <String>[
            '-mode',
            'refresh',
            '-gallery-root',
            '<请配置Gallery目录路径>',
            '-concurrency',
            '10',
            '-batch',
            '160',
            '-resize',
            '0',
            '-resizePreview',
            '0',
            '-resizeThumb',
            '0',
          ],
        ),
      ],
      selectedPresetId: 'ingest',
      dangerousOperation: true,
      hiddenByDefault: false,
      supportsGracefulStop: true,
    ),
    TaskProfile(
      id: 'comic-indexer',
      type: TaskType.comicIndexer,
      name: 'Comic Indexer',
      executablePath: '',
      presets: <ArgPreset>[
        ArgPreset(
          id: 'refresh',
          name: 'Comic Refresh',
          args: <String>[
            '-mode',
            'refresh',
            '-root',
            '<请配置Comic目录路径>',
          ],
        ),
        ArgPreset(
          id: 'full-reindex',
          name: 'Comic FullReindex',
          args: <String>[
            '-mode',
            'full-reindex',
            '-root',
            '<请配置Comic目录路径>',
          ],
        ),
      ],
      selectedPresetId: 'refresh',
      dangerousOperation: true,
      hiddenByDefault: false,
      supportsGracefulStop: false,
    ),
  ];
}
