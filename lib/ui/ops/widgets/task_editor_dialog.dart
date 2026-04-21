import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:northstar/application/ops/providers/core_services_provider.dart';
import 'package:northstar/domain/ops/models/arg_preset.dart';
import 'package:northstar/domain/ops/models/task_profile.dart';
import 'package:northstar/domain/ops/utils/arg_parser.dart';
import 'package:northstar/shared/utils/util_service.dart';

class TaskEditorDialog extends ConsumerStatefulWidget {
  final TaskProfile? initial;

  const TaskEditorDialog({super.key, this.initial});

  @override
  ConsumerState<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends ConsumerState<TaskEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _exeController;
  late final TextEditingController _workingDirController;

  late TaskType _type;
  late bool _dangerousOperation;
  late bool _hiddenByDefault;
  late bool _supportsGracefulStop;
  late String _selectedPresetId;

  final List<_PresetFormItem> _presets = <_PresetFormItem>[];
  String _error = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;

    _nameController = TextEditingController(text: initial?.name ?? '');
    _exeController = TextEditingController(text: initial?.executablePath ?? '');
    _workingDirController = TextEditingController(
      text: initial?.workingDirectory ?? '',
    );

    _type = initial?.type ?? TaskType.custom;
    _dangerousOperation = initial?.dangerousOperation ?? false;
    _hiddenByDefault = initial?.hiddenByDefault ?? false;
    _supportsGracefulStop = initial?.supportsGracefulStop ?? false;

    if (initial != null && initial.presets.isNotEmpty) {
      _selectedPresetId = initial.selectedPresetId;
      for (final preset in initial.presets) {
        _presets.add(
          _PresetFormItem(
            id: preset.id,
            nameController: TextEditingController(text: preset.name),
            argsController: TextEditingController(
              text: toArgumentLine(preset.args),
            ),
          ),
        );
      }
    } else {
      final firstId = 'preset-${generateId()}';
      _selectedPresetId = firstId;
      _presets.add(
        _PresetFormItem(
          id: firstId,
          nameController: TextEditingController(text: '默认参数'),
          argsController: TextEditingController(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _exeController.dispose();
    _workingDirController.dispose();
    for (final item in _presets) {
      item.nameController.dispose();
      item.argsController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增任务' : '编辑任务'),
      content: SizedBox(
        width: 840,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: '任务类型'),
                items: TaskType.values
                    .map(
                      (type) => DropdownMenuItem<TaskType>(
                        value: type,
                        child: Text(_taskTypeLabel(type)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _type = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _exeController,
                      decoration: const InputDecoration(
                        labelText: '可执行文件路径 (.exe)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _pickExecutable,
                    tooltip: '浏览 exe',
                    icon: const Icon(Icons.file_open_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _workingDirController,
                      decoration: const InputDecoration(
                        labelText: '工作目录 (可选)',
                        hintText: '留空则使用程序默认工作目录',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _pickWorkingDirectory,
                    tooltip: '浏览目录',
                    icon: const Icon(Icons.folder_open_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _SwitchCell(
                    title: '危险操作',
                    value: _dangerousOperation,
                    onChanged: (value) {
                      setState(() {
                        _dangerousOperation = value;
                      });
                    },
                  ),
                  _SwitchCell(
                    title: '默认隐藏',
                    value: _hiddenByDefault,
                    onChanged: (value) {
                      setState(() {
                        _hiddenByDefault = value;
                      });
                    },
                  ),
                  _SwitchCell(
                    title: '支持温和中断',
                    value: _supportsGracefulStop,
                    onChanged: (value) {
                      setState(() {
                        _supportsGracefulStop = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('参数预设', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addPreset,
                    icon: const Icon(Icons.add),
                    label: const Text('添加预设'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_presets.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _selectedPresetId,
                  decoration: const InputDecoration(labelText: '默认预设'),
                  items: _presets
                      .map(
                        (item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text(
                            item.nameController.text.trim().isEmpty
                                ? item.id
                                : item.nameController.text.trim(),
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedPresetId = value;
                    });
                  },
                ),
              const SizedBox(height: 12),
              for (final item in _presets)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: item.nameController,
                                decoration: const InputDecoration(
                                  labelText: '预设名称',
                                ),
                                onChanged: (_) {
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _presets.length <= 1
                                  ? null
                                  : () => _removePreset(item.id),
                              tooltip: '删除预设',
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: item.argsController,
                          decoration: const InputDecoration(
                            labelText: '参数字符串',
                            hintText:
                                '-mode ingest -gallery-root "D:\\Assets\\Gallery"',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Future<void> _pickExecutable() async {
    final picker = ref.read(pathPickerServiceProvider);
    final initialDirectory = _initialExecutableDirectory();
    final path = await picker.pickExecutable(
      initialDirectory: initialDirectory,
    );
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _exeController.text = path;
      if (_workingDirController.text.trim().isEmpty) {
        final parentPath = File(path).parent.path;
        if (Directory(parentPath).existsSync()) {
          _workingDirController.text = parentPath;
        }
      }
    });
  }

  Future<void> _pickWorkingDirectory() async {
    final picker = ref.read(pathPickerServiceProvider);
    final path = await picker.pickDirectory(
      initialDirectory: _workingDirController.text.trim().isEmpty
          ? _initialExecutableDirectory()
          : _workingDirController.text.trim(),
    );
    if (path == null || !mounted) {
      return;
    }
    setState(() {
      _workingDirController.text = path;
    });
  }

  String? _initialExecutableDirectory() {
    final executablePath = _exeController.text.trim();
    if (executablePath.isEmpty) {
      return null;
    }

    try {
      final parentPath = File(executablePath).parent.path;
      if (parentPath.trim().isEmpty) {
        return null;
      }

      final directory = Directory(parentPath);
      if (!directory.existsSync()) {
        return null;
      }

      return directory.path;
    } catch (_) {
      return null;
    }
  }

  void _addPreset() {
    final id = 'preset-${generateId()}';
    setState(() {
      _presets.add(
        _PresetFormItem(
          id: id,
          nameController: TextEditingController(text: '新预设'),
          argsController: TextEditingController(),
        ),
      );
      _selectedPresetId = id;
    });
  }

  void _removePreset(String id) {
    setState(() {
      final target = _presets.firstWhere((item) => item.id == id);
      target.nameController.dispose();
      target.argsController.dispose();
      _presets.removeWhere((item) => item.id == id);
      if (_selectedPresetId == id && _presets.isNotEmpty) {
        _selectedPresetId = _presets.first.id;
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = '任务名称不能为空';
      });
      return;
    }

    if (_presets.isEmpty) {
      setState(() {
        _error = '至少需要一个参数预设';
      });
      return;
    }

    final presets = <ArgPreset>[];
    for (final item in _presets) {
      final presetName = item.nameController.text.trim();
      if (presetName.isEmpty) {
        setState(() {
          _error = '预设名称不能为空';
        });
        return;
      }

      presets.add(
        ArgPreset(
          id: item.id,
          name: presetName,
          args: parseArgumentLine(item.argsController.text.trim()),
        ),
      );
    }

    if (!presets.any((item) => item.id == _selectedPresetId)) {
      _selectedPresetId = presets.first.id;
    }

    final profile = TaskProfile(
      id: widget.initial?.id ?? 'task-${generateId()}',
      type: _type,
      name: name,
      executablePath: _exeController.text.trim(),
      workingDirectory: _workingDirController.text.trim(),
      presets: presets,
      selectedPresetId: _selectedPresetId,
      dangerousOperation: _dangerousOperation,
      hiddenByDefault: _hiddenByDefault,
      supportsGracefulStop: _supportsGracefulStop,
    );

    Navigator.of(context).pop(profile);
  }

  String _taskTypeLabel(TaskType type) {
    switch (type) {
      case TaskType.monarch:
        return 'Monarch';
      case TaskType.gallery:
        return 'Gallery';
      case TaskType.comicIndexer:
        return 'Comic Indexer';
      case TaskType.custom:
        return 'Custom';
    }
  }
}

class _SwitchCell extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCell({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        const SizedBox(width: 6),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _PresetFormItem {
  final String id;
  final TextEditingController nameController;
  final TextEditingController argsController;

  _PresetFormItem({
    required this.id,
    required this.nameController,
    required this.argsController,
  });
}
