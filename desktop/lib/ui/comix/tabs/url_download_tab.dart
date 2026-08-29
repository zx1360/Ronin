import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';

/// 网址下载 Tab：粘贴漫画详情页 URL（支持多行/多个并发），
/// 服务端自动识别站点并启动对应爬虫下载。
class UrlDownloadTab extends ConsumerStatefulWidget {
  const UrlDownloadTab({super.key});

  @override
  ConsumerState<UrlDownloadTab> createState() => _UrlDownloadTabState();
}

class _UrlDownloadTabState extends ConsumerState<UrlDownloadTab> {
  final _urlsController = TextEditingController();
  final _latestController = TextEditingController();
  bool _submitting = false;
  List<Map<String, dynamic>>? _results;

  @override
  void dispose() {
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
      _results = null;
    });

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final latest = int.tryParse(_latestController.text.trim());
      final results = await ref
          .read(comixApiClientProvider)
          .downloadUrls(settings, urls, latest: latest);
      if (!mounted) return;
      setState(() => _results = results);
      ref.invalidate(comixComicsProvider);
      final okCount = results.where((r) => r['task_id'] != null).length;
      final failCount = results.length - okCount;
      _snack(
        okCount > 0
            ? '已启动 $okCount 个下载任务${failCount > 0 ? '，$failCount 个失败' : ''}，可在任务面板查看进度'
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
                      '留空时按增量语义下载全部未完成章节（已下载的自动跳过）',
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
              if (_results != null) ...[
                const Divider(height: 24),
                Text('提交结果', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppDimens.spacingS),
                for (final item in _results!)
                  _ResultTile(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> item;

  const _ResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item['url'] as String? ?? '';
    final site = item['site'] as String? ?? '';
    final taskId = item['task_id'] as String? ?? '';
    final error = item['error'] as String? ?? '';

    final ok = taskId.isNotEmpty;
    final color = ok ? Colors.greenAccent.shade400 : Theme.of(context).colorScheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: color,
          size: 20,
        ),
        title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          ok ? '站点: $site · 任务: $taskId（已在任务面板运行）' : error,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
