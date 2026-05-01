import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:northstar/application/ops/providers/runtime_process_provider.dart';
import 'package:northstar/application/ops/providers/task_profiles_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/ops/models/process_log_entry.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  final TextEditingController _filterController = TextEditingController();
  String? _selectedTaskId;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(taskProfilesControllerProvider);
    final runtimeBoard = ref.watch(runtimeProcessControllerProvider);

    if (tasks.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(title: '日志'),
          Expanded(child: Center(child: Text('暂无任务，请先在任务管理页创建任务'))),
        ],
      );
    }

    _selectedTaskId ??= tasks.first.id;
    if (!tasks.any((task) => task.id == _selectedTaskId)) {
      _selectedTaskId = tasks.first.id;
    }

    final keyword = _filterController.text.trim().toLowerCase();
    final rawLogs = runtimeBoard.logs[_selectedTaskId] ?? const <ProcessLogEntry>[];
    final filteredLogs = rawLogs.where((item) {
      if (keyword.isEmpty) {
        return true;
      }
      return item.text.toLowerCase().contains(keyword);
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '日志'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTaskId,
                        decoration: const InputDecoration(labelText: '任务'),
                        items: tasks
                            .map(
                              (task) => DropdownMenuItem<String>(
                                value: task.id,
                                child: Text(task.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedTaskId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        decoration: const InputDecoration(
                          labelText: '关键字过滤',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedTaskId == null) {
                          return;
                        }
                        ref.read(runtimeProcessControllerProvider.notifier).clearLogs(_selectedTaskId!);
                      },
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('清空'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: filteredLogs.isEmpty
                          ? null
                          : () async {
                              final text = filteredLogs
                                  .map((item) => _formatLine(item))
                                  .join('\n');
                              await Clipboard.setData(ClipboardData(text: text));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('日志已复制')),
                                );
                              }
                            },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('复制'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spacingM),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.paddingM),
                      child: filteredLogs.isEmpty
                          ? const Center(child: Text('暂无日志'))
                          : ListView.builder(
                              itemCount: filteredLogs.length,
                              itemBuilder: (context, index) {
                                final item = filteredLogs[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    _formatLine(item),
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      color: _streamColor(context, item.streamType),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatLine(ProcessLogEntry entry) {
    final time = DateFormat('HH:mm:ss').format(entry.time);
    return '[$time][${entry.streamType.name}] ${entry.text}';
  }

  Color _streamColor(BuildContext context, LogStreamType streamType) {
    switch (streamType) {
      case LogStreamType.stdout:
        return Theme.of(context).colorScheme.onSurface;
      case LogStreamType.stderr:
        return Theme.of(context).colorScheme.error;
      case LogStreamType.system:
        return Colors.blueAccent.shade200;
    }
  }
}
