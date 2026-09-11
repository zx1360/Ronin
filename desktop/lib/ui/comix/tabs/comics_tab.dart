import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
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

    // 同步删除：显示加载遮罩（大漫画文件删除可能耗时）。
    // 该对话框挂在根 Navigator 上且不可关闭，因此 pop 必须用 await 之前捕获的
    // NavigatorState——若用 mounted 门控，widget 卸载时会留下无法关闭的死锁弹窗。
    final rootNavigator = Navigator.of(context, rootNavigator: true);
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
      if (rootNavigator.canPop()) rootNavigator.pop();
      ref.invalidate(comixComicsProvider);
      final data = result['data'];
      // 先判 keepFiles：保留文件是用户主动选择，不能报成"文件清理失败"
      var message = '「${comic.title}」已删除';
      if (options.keepFiles) {
        message = '「${comic.title}」记录已删除（本地文件已保留）';
      } else if (data is Map<String, dynamic> && data['files_removed'] == false) {
        message = '记录已删除，文件清理失败，残留目录：${data['leftover_path'] ?? '未知'}';
      }
      _snack(message);
    } catch (e) {
      if (rootNavigator.canPop()) rootNavigator.pop();
      // 删除失败也要刷新：服务端可能已部分完成（如 DB 已删、文件残留）
      ref.invalidate(comixComicsProvider);
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
    final baseUrl = ref
        .watch(opsSettingsControllerProvider)
        .apiBaseUrl
        .trim()
        .replaceAll(RegExp(r'/+$'), '');
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
                    baseUrl: baseUrl,
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
  final String baseUrl;
  final VoidCallback onDownload;
  final VoidCallback onUpdateCheck;
  final VoidCallback onChapters;
  final VoidCallback onDelete;

  const _ComicTile({
    required this.comic,
    required this.baseUrl,
    required this.onDownload,
    required this.onUpdateCheck,
    required this.onChapters,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 待下载 = 未下载且未失败；failed 必须单独列出，否则会被同时算作"待下载"
    final pending = comic.pending;
    final coverUrl =
        comic.coverImage.isEmpty ? '' : '$baseUrl/static/${comic.coverImage}';
    return ListTile(
      dense: true,
      leading: _coverThumb(context, coverUrl),
      title: Text(
        comic.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '[${comic.siteName}] 已下载 ${comic.downloaded}/${comic.totalChapters} 章'
        '${comic.failed > 0 ? ' · 失败 ${comic.failed}' : ''}'
        '${pending > 0 ? ' · 待下载 $pending' : ''}'
        '${comic.totalChapters == 0 ? ' · 未解析到章节' : ''}'
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

  /// 封面缩略图：无封面时用占位图标，让"缺封面"这件事可见。
  Widget _coverThumb(BuildContext context, String url) {
    if (url.isEmpty) {
      return Tooltip(
        message: '无封面（该漫画尚无已下载章节时不会生成封面）',
        child: Container(
          width: 36,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.image_not_supported_outlined, size: 16),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: 36,
        height: 48,
        fit: BoxFit.cover,
        // 自签证书由 CertTrust 的全局 HttpOverrides 处理；
        // 封面缺失/加载失败不应让整个列表报错。
        errorBuilder: (_, __, ___) => Container(
          width: 36,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.broken_image_outlined, size: 16),
        ),
      ),
    );
  }
}
