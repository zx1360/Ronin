import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/application/comix/providers/comix_providers.dart';
import 'package:northstar/application/ops/providers/ops_settings_provider.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/ui/comix/widgets/comix_dialogs.dart';

/// 漫画列表 Tab：工具栏（全站追更/孤儿回收/刷新）+ 已登记漫画列表。
/// 删除为 Go 端直查库同步执行（可 keep-files），带加载反馈。
class ComicsTab extends ConsumerStatefulWidget {
  const ComicsTab({super.key});

  @override
  ConsumerState<ComicsTab> createState() => _ComicsTabState();
}

class _ComicsTabState extends ConsumerState<ComicsTab> {
  Future<void> _download(ComixComic comic) async {
    final options = await showDownloadDialog(context, comic);
    if (options == null) return;
    try {
      await ref
          .read(comixBoardProvider.notifier)
          .startTask('download', options.toBody(comic.comicId));
      _snack('已提交下载任务：${comic.title}');
    } catch (e) {
      _snack('提交下载失败: $e');
    }
  }

  Future<void> _updateCheck({int? comicId, String? title, bool all = false}) async {
    final options = await showUpdateCheckDialog(
      context,
      comicTitle: title,
      all: all,
    );
    if (options == null) return;
    try {
      await ref
          .read(comixBoardProvider.notifier)
          .startTask('update-check', options.toBody(comicId: comicId, all: all));
      _snack(all ? '已提交全站追更检查' : '已提交追更检查：$title');
    } catch (e) {
      _snack('提交追更检查失败: $e');
    }
  }

  Future<void> _delete(ComixComic comic) async {
    final options = await showDeleteComicDialog(context, comic);
    if (options == null) return;
    if (!mounted) return;

    // 同步删除：显示加载遮罩（大漫画文件删除可能耗时）
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在删除，请稍候...')),
            ],
          ),
        ),
      ),
    );

    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final result = await ref
          .read(comixApiClientProvider)
          .deleteComic(settings, comic.comicId, keepFiles: options.keepFiles);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      ref.invalidate(comixComicsProvider);
      final data = result['data'];
      var message = '「${comic.title}」已删除';
      if (data is Map<String, dynamic>) {
        if (data['files_removed'] == false) {
          message = '记录已删除，文件清理失败，残留目录：${data['leftover_path']}';
        } else if (options.keepFiles) {
          message = '记录已删除（文件已保留）';
        }
      }
      _snack(message);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _snack('删除失败: $e');
    }
  }

  Future<void> _chapters(ComixComic comic) async {
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      final chapters = await ref
          .read(comixApiClientProvider)
          .fetchChapters(settings, comic.comicId);
      if (!mounted) return;
      await showChaptersDialog(context, comic: comic, chapters: chapters);
    } catch (e) {
      _snack('加载章节失败: $e');
    }
  }

  Future<void> _clean() async {
    try {
      await ref.read(comixBoardProvider.notifier).startTask('clean', {});
      _snack('已提交孤儿回收任务');
    } catch (e) {
      _snack('提交清理失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final comics = ref.watch(comixComicsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.paddingL,
            AppDimens.paddingM,
            AppDimens.paddingL,
            0,
          ),
          child: Wrap(
            spacing: AppDimens.spacingM,
            runSpacing: AppDimens.spacingS,
            children: [
              ElevatedButton.icon(
                onPressed: () => _updateCheck(all: true),
                icon: const Icon(Icons.update_rounded, size: 18),
                label: const Text('全站追更检查'),
              ),
              OutlinedButton.icon(
                onPressed: _clean,
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('孤儿回收 clean'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(comixComicsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新列表'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimens.spacingM),
        Expanded(
          child: comics.when(
            data: (list) {
              if (list.isEmpty) {
                return const Center(child: Text('暂无已登记漫画'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.paddingL,
                  vertical: AppDimens.paddingS,
                ),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final comic = list[index];
                  return _ComicTile(
                    comic: comic,
                    onDownload: () => _download(comic),
                    onUpdateCheck: () => _updateCheck(
                      comicId: comic.comicId,
                      title: comic.title,
                    ),
                    onChapters: () => _chapters(comic),
                    onDelete: () => _delete(comic),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('漫画列表加载失败: $e'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(comixComicsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComicTile extends StatelessWidget {
  final ComixComic comic;
  final VoidCallback onDownload;
  final VoidCallback onUpdateCheck;
  final VoidCallback onChapters;
  final VoidCallback onDelete;

  const _ComicTile({
    required this.comic,
    required this.onDownload,
    required this.onUpdateCheck,
    required this.onChapters,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pending = comic.totalChapters - comic.downloaded;
    return ListTile(
      dense: true,
      title: Text(
        comic.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '[${comic.siteName}] 已下载 ${comic.downloaded}/${comic.totalChapters} 章'
        '${comic.failed > 0 ? ' · 失败 ${comic.failed}' : ''}'
        '${pending > 0 ? ' · 待下载 $pending' : ''}'
        '${comic.isLegacy ? ' · legacy(不参与追更)' : ''}',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: '下载',
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '追更检查',
            onPressed: comic.isLegacy ? null : onUpdateCheck,
            icon: const Icon(Icons.update_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '章节',
            onPressed: onChapters,
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: '删除',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
