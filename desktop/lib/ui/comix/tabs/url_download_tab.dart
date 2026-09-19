import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/ui/comix/widgets/comix_widgets.dart';

/// 单个 URL 的提交与实时状态。
class UrlTaskResult {
  final String url;
  final String site;
  final String? taskId;
  final ComixTaskStatus status;
  final String? error;
  final String? summary;

  const UrlTaskResult({
    required this.url,
    required this.site,
    required this.taskId,
    this.status = ComixTaskStatus.unknown,
    this.error,
    this.summary,
  });

  factory UrlTaskResult.fromSubmit(Map<String, dynamic> item) {
    final taskId = item['task_id'] as String?;
    return UrlTaskResult(
      url: item['url'] as String? ?? '',
      site: item['site'] as String? ?? '',
      taskId: taskId,
      status: taskId == null
          ? ComixTaskStatus.unknown
          : ComixTaskStatus.parse(item['status'] as String?),
      error: item['error'] as String?,
    );
  }
}

/// 网址下载 Tab：粘贴漫画详情页 URL（支持多行/多个并发），
/// 服务端自动识别站点并启动对应爬虫下载；提交结果随后端轮询实时更新。
class UrlDownloadTab extends ConsumerStatefulWidget {
  const UrlDownloadTab({super.key});

  @override
  ConsumerState<UrlDownloadTab> createState() => _UrlDownloadTabState();
}

class _UrlDownloadTabState extends ConsumerState<UrlDownloadTab>
    with AutomaticKeepAliveClientMixin {
  final _urlsController = TextEditingController();
  final _latestController = TextEditingController();
  bool _submitting = false;
  List<UrlTaskResult> _results = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _urlsController.dispose();
    _latestController.dispose();
    super.dispose();
  }

  /// 用任务面板的最新快照刷新本页提交结果。
  ///
  /// 轮询完全由 [comixBoardProvider] 负责（按需启停），本页只做映射，
  /// 避免再起一个独立定时器重复请求 `/API/comix/tasks`。
  void _syncResults(List<ComixTask> tasks) {
    if (_results.isEmpty) return;
    final byId = <String, ComixTask>{for (final t in tasks) t.id: t};
    var changed = false;
    final next = _results.map((item) {
      final id = item.taskId;
      if (id == null) return item;
      final task = byId[id];
      if (task == null) return item;

      final error = task.isFailure && task.failureReason.isNotEmpty
          ? task.failureReason
          : null;
      final summary = comixTaskSummary(task);
      final newSummary = summary.isEmpty ? null : summary;
      if (item.status == task.status &&
          item.error == error &&
          item.summary == newSummary) {
        return item;
      }
      changed = true;
      return UrlTaskResult(
        url: item.url,
        site: item.site,
        taskId: item.taskId,
        status: task.status,
        error: error,
        summary: newSummary,
      );
    }).toList(growable: false);

    if (changed) {
      setState(() => _results = next);
    }
  }

  Future<void> _submit() async {
    final urls = _urlsController.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (urls.isEmpty) {
      _snack('请先粘贴至少一个漫画详情页网址');
      return;
    }
    final latestText = _latestController.text.trim();
    if (latestText.isNotEmpty) {
      final parsed = int.tryParse(latestText);
      if (parsed == null || parsed <= 0) {
        // 非法输入会被后端当作"留空=全部"，静默变成全量下载，必须拦下
        _snack('"仅下载最新 N 章"必须是正整数（留空表示全部）');
        return;
      }
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _results = [];
    });

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final latest = int.tryParse(latestText);
      final results = await ref
          .read(comixApiClientProvider)
          .downloadUrls(settings, urls, latest: latest);
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _results = results.map(UrlTaskResult.fromSubmit).toList();
      });

      // 任务面板刷新并（在有任务时）开启轮询；本页结果随其快照更新。
      final taskIds = _results
          .map((r) => r.taskId)
          .whereType<String>()
          .toList(growable: false);
      ref.read(comixBoardProvider.notifier).trackSubmitted(taskIds);

      final okCount = _results.where((r) => r.taskId != null).length;
      final failCount = _results.length - okCount;
      if (okCount == 0) {
        _snack(
          '提交失败：${failCount == 0 ? '服务端未返回任何任务' : '$failCount 个网址均未能启动任务'}',
        );
      } else {
        _snack(
          '已启动 $okCount 个下载任务${failCount > 0 ? '，$failCount 个提交失败' : ''}，可在下方查看进度与结果',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _snack('提交失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(comixBoardProvider, (_, next) => _syncResults(next.tasks));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.paddingL),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('网址下载', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '粘贴漫画详情页网址，自动识别站点并下载（支持多行，多个任务并发进行）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimens.spacingM),
              TextField(
                controller: _urlsController,
                maxLines: 8,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: '漫画详情页网址（每行一个）',
                  hintText: 'https://www.xmanhua.net/m27836/\nhttps://www.morui.com/comic/1165/',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppDimens.spacingM),
              Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _latestController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '仅下载最新 N 章（留空=全部）',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spacingM),
                  Expanded(
                    child: Text(
                      '留空将下载全部未完成章节（大章节漫画耗时较长，建议先限量试跑）',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spacingM),
              ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_submitting ? '提交中...' : '开始下载'),
              ),
              if (_results.isNotEmpty) ...[
                const Divider(height: 24),
                Text('提交结果', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppDimens.spacingS),
                for (final item in _results) _ResultTile(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final UrlTaskResult item;

  const _ResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final ok = item.taskId != null;
    // 进程结束但业务 ok=false（后端记为 finished）也算失败，
    // 不能画成绿色"完成"。
    final businessError = item.status == ComixTaskStatus.finished &&
        item.error != null &&
        item.error!.isNotEmpty;
    final failed = !ok ||
        businessError ||
        item.status == ComixTaskStatus.failed ||
        item.status == ComixTaskStatus.killed;
    final color = switch (item.status) {
      ComixTaskStatus.running => Colors.blueAccent,
      ComixTaskStatus.finished => businessError
          ? Colors.redAccent
          : Colors.greenAccent.shade400,
      ComixTaskStatus.failed => Colors.redAccent,
      ComixTaskStatus.killed => Colors.orange,
      ComixTaskStatus.unknown => ok
          ? Colors.blueGrey
          : Theme.of(context).colorScheme.error,
    };
    final statusLabel = switch (item.status) {
      ComixTaskStatus.running => '运行中',
      ComixTaskStatus.finished => businessError ? '业务错误' : '完成',
      ComixTaskStatus.failed => '失败',
      ComixTaskStatus.killed => '已中断',
      ComixTaskStatus.unknown => ok ? '等待中' : '提交失败',
    };

    final subtitle = item.taskId == null
        ? (item.error ?? '未知错误（可能是站点不支持或 comix 集成不可用）')
        : '站点: ${item.site} · 任务: ${item.taskId} · $statusLabel'
            '${item.error != null && item.error!.isNotEmpty ? ' · ${item.error}' : ''}'
            '${item.summary != null && item.summary!.isNotEmpty ? '\n${item.summary}' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: item.status == ComixTaskStatus.running
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                failed ? Icons.error_outline : Icons.check_circle_outline,
                color: color,
                size: 20,
              ),
        title: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 4, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
