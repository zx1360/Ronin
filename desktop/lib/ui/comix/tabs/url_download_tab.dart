import 'dart:async';

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
  ComixTaskStatus status;
  String? error;
  String? summary;

  UrlTaskResult({
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
/// 服务端自动识别站点并启动对应爬虫下载；列表实时刷新任务状态。
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
  Timer? _statusTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _urlsController.dispose();
    _latestController.dispose();
    super.dispose();
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
    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _results = [];
    });

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final latest = int.tryParse(_latestController.text.trim());
      final results = await ref
          .read(comixApiClientProvider)
          .downloadUrls(settings, urls, latest: latest);
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _results = results.map(UrlTaskResult.fromSubmit).toList();
      });

      // 任务面板立即可见 + 本列表实时轮询任务状态
      ref.read(comixBoardProvider.notifier).refresh();
      ref.invalidate(comixComicsProvider);

      final okCount = _results.where((r) => r.taskId != null).length;
      final failCount = _results.length - okCount;
      _snack(
        okCount > 0
            ? '已启动 $okCount 个下载任务${failCount > 0 ? '，$failCount 个失败' : ''}，进度见下方与任务面板'
            : '提交失败：$failCount 个网址均无法识别',
      );
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
    final color = switch (item.status) {
      ComixTaskStatus.running => Colors.blueAccent,
      ComixTaskStatus.finished => Colors.greenAccent.shade400,
      ComixTaskStatus.failed => Colors.redAccent,
      ComixTaskStatus.killed => Colors.orange,
      ComixTaskStatus.unknown => ok
          ? Colors.blueGrey
          : Theme.of(context).colorScheme.error,
    };
    final statusLabel = switch (item.status) {
      ComixTaskStatus.running => '运行中',
      ComixTaskStatus.finished => '完成',
      ComixTaskStatus.failed => '失败',
      ComixTaskStatus.killed => '已中断',
      ComixTaskStatus.unknown => ok ? '等待中' : '站点识别失败',
    };

    final subtitle = item.taskId == null
        ? (item.error ?? '未知错误')
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
                item.status == ComixTaskStatus.finished
                    ? Icons.check_circle_outline
                    : (item.status == ComixTaskStatus.failed ||
                            item.taskId == null)
                        ? Icons.error_outline
                        : Icons.info_outline,
                color: color,
                size: 20,
              ),
        title: Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
