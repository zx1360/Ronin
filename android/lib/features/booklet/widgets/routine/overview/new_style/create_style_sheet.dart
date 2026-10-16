import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/providers/providers.dart';
import 'package:torrid/features/booklet/widgets/routine/overview/constants/global_constants.dart';
import 'newtask_inputitem.dart';

class CreateStyleSheet extends ConsumerStatefulWidget {
  const CreateStyleSheet({super.key});

  @override
  ConsumerState<CreateStyleSheet> createState() => _CreateStyleSheetState();
}

class _CreateStyleSheetState extends ConsumerState<CreateStyleSheet> {
  final _tasks = [NewTask()];
  bool _busy = false;

  @override
  void dispose() {
    for (final task in _tasks) {
      task.dispose();
    }
    super.dispose();
  }

  void _error(Object error) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$error')));

  Future<void> _pickImage(NewTask task) async {
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null && mounted && _tasks.contains(task)) {
        setState(() => task.imagePath = picked.path);
      }
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final valid = _tasks
        .where((task) => task.titleCtrl.text.trim().isNotEmpty)
        .toList();
    if (valid.isEmpty) {
      _error('至少需要一个非空任务');
      return;
    }
    setState(() => _busy = true);
    final imported = <String>[];
    var committed = false;
    try {
      final hasToday =
          ref
              .read(styleBoxProvider)
              .values
              .any((style) => isSameDay(style.startDate, DateTime.now())) ||
          ref
              .read(recordBoxProvider)
              .values
              .any((record) => isSameDay(record.date, DateTime.now()));
      if (hasToday) {
        final confirmed = await showConfirmDialog(
          context: context,
          title: '替换今天的样式',
          content: '保存后将替换今天创建的样式并清除今天的打卡，往期记录保留。取消不会修改已有数据。',
          confirmFunc: () {},
        );
        if (confirmed != true || !mounted) return;
      }
      final tasks = <Task>[];
      for (final task in valid) {
        var image = '';
        if (task.imagePath.isNotEmpty) {
          image = await IoService.importUserImage(
            'img_storage/booklet',
            File(task.imagePath),
          );
          imported.add(image);
        }
        tasks.add(
          Task.noId(
            title: task.titleCtrl.text.trim(),
            description: task.descCtrl.text.trim(),
            image: image,
          ),
        );
      }
      if (!mounted) return;
      final style = Style.newOne(getTodayDate(), tasks);
      await ref
          .read(routineServiceProvider.notifier)
          .createStyle(style: style, replaceToday: hasToday);
      committed = true;
      if (mounted) Navigator.pop(context, style);
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (!committed) {
        for (final key in imported) {
          try {
            await IoService.deleteUserFile(key);
          } catch (error) {
            AppLogger().warning('清理未保存的任务图片失败: $error');
          }
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: AbsorbPointer(
          absorbing: _busy,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('创建新打卡样式', style: noteTitle),
                const SizedBox(height: 16),
                for (var index = 0; index < _tasks.length; index++)
                  KeyedSubtree(
                    key: ObjectKey(_tasks[index]),
                    child: inputItem(
                      task: _tasks[index],
                      index: index,
                      onSelectImage: () => _pickImage(_tasks[index]),
                      onDelete: () {
                        if (_tasks.length <= 1) return;
                        final removed = _tasks[index];
                        setState(() => _tasks.removeAt(index));
                        removed.dispose();
                      },
                    ),
                  ),
                TextButton.icon(
                  onPressed: _tasks.length >= maxTaskCount
                      ? null
                      : () => setState(() => _tasks.add(NewTask())),
                  icon: const Icon(Icons.add),
                  label: Text('添加任务（最多 $maxTaskCount 个）'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? '正在处理…' : '确认创建'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
