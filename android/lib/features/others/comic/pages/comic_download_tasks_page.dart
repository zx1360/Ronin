import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/others/comic/models/comic_download_task.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';

class ComicDownloadTasksPage extends ConsumerWidget {
  const ComicDownloadTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(comicDownloadTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画下载任务'),
        centerTitle: true,
        actions: [
          if (tasks.any((task) => task.isTerminal))
            IconButton(
              tooltip: '清理已结束任务',
              onPressed: () {
                ref
                    .read(comicDownloadTasksProvider.notifier)
                    .clearFinishedTasks();
              },
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(
              child: Text('当前没有下载任务', style: TextStyle(color: Colors.black54)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskCard(task: task);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: tasks.length,
            ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final ComicDownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(comicDownloadTasksProvider.notifier);
    final progressValue = task.totalImages <= 0
        ? null
        : task.progress.clamp(0.0, 1.0).toDouble();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.comicName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: task.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '章节: ${task.completedChapters}/${task.totalChapters}    图片: ${task.downloadedImages}/${task.totalImages}',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (task.currentChapterName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '当前: ${task.currentChapterName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            if (task.errorMessage != null && task.errorMessage!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '错误: ${task.errorMessage}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progressValue,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == ComicDownloadTaskStatus.running)
                  TextButton.icon(
                    onPressed: () => notifier.pauseTask(task.taskId),
                    icon: const Icon(Icons.pause),
                    label: const Text('暂停'),
                  ),
                if (task.canResume)
                  TextButton.icon(
                    onPressed: () => notifier.resumeTask(task.taskId),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('继续'),
                  ),
                if (task.hasActiveWork)
                  TextButton.icon(
                    onPressed: () async {
                      final removeFiles = await _askCancelMode(context);
                      if (removeFiles == null) return;
                      await notifier.cancelTask(
                        task.taskId,
                        deleteLocalFiles: removeFiles,
                      );
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('取消'),
                  ),
                if (task.isTerminal)
                  TextButton.icon(
                    onPressed: () => notifier.removeTask(task.taskId),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('移除'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _askCancelMode(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('取消下载任务'),
          content: const Text('是否同时删除当前漫画已下载到本地的文件?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('仅取消任务'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取消并删除本地文件'),
            ),
          ],
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ComicDownloadTaskStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ComicDownloadTaskStatus.queued => Colors.blueGrey,
      ComicDownloadTaskStatus.running => Colors.blue,
      ComicDownloadTaskStatus.paused => Colors.orange,
      ComicDownloadTaskStatus.retryWaiting => Colors.deepOrange,
      ComicDownloadTaskStatus.completed => Colors.green,
      ComicDownloadTaskStatus.failed => Colors.red,
      ComicDownloadTaskStatus.canceled => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
