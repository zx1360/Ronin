import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/comix/comix_providers.dart';
import 'package:northstar/core/providers/ops/ops_overview_provider.dart';
import 'package:northstar/core/providers/ops/ops_settings_provider.dart';
import 'package:northstar/domain/comix/models/comix_models.dart';
import 'package:northstar/infrastructure/api_http_helper.dart';
import 'package:northstar/ui/comix/widgets/comix_dialogs.dart';

/// 漫画库 Tab：书库管理与爬虫操作的一体化视图。
///
/// 数据来自单一接口 `/API/comix/list`（含下载进度 + 公开/已读/封面等管理字段），
/// 因此封面网格既能做书库管理（公开·隐藏/已读/换封面/删除），
/// 也能直接发起爬虫任务（增量下载/追更检查/章节/孤儿回收）。
class ComicsLibraryTab extends ConsumerStatefulWidget {
  const ComicsLibraryTab({super.key});

  @override
  ConsumerState<ComicsLibraryTab> createState() => _ComicsLibraryTabState();
}

class _ComicsLibraryTabState extends ConsumerState<ComicsLibraryTab> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 爬虫任务 ---

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

  Future<void> _updateCheck({
    int? comicId,
    String? title,
    bool all = false,
  }) async {
    final options = await showUpdateCheckDialog(
      context,
      comicTitle: title,
      all: all,
    );
    if (options == null) return;
    try {
      await ref
          .read(comixBoardProvider.notifier)
          .startTask(
            'update-check',
            options.toBody(comicId: comicId, all: all),
          );
      _snack(all ? '已提交全站追更检查' : '已提交追更检查：$title');
    } catch (e) {
      _snack('提交追更检查失败: $e');
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

  // --- 书库管理 ---

  /// 管理字段更新后重取列表：下载进度等由服务端聚合，本地改写容易与服务端不一致。
  void _refreshComics() => ref.invalidate(comixComicsProvider);

  Future<void> _togglePublic(ComixComic comic) async {
    final next = !comic.isPublic;
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      await ref.read(comixApiClientProvider).updateComicMeta(
        settings,
        comic.comicId,
        {'is_public': next},
      );
      _refreshComics();
      _snack(next ? '「${comic.title}」已设为公开' : '「${comic.title}」已设为隐藏');
    } catch (e) {
      _snack('更新失败: $e');
    }
  }

  Future<void> _toggleReaded(ComixComic comic) async {
    final next = !comic.readed;
    try {
      final settings = ref.read(opsSettingsControllerProvider);
      await ref.read(comixApiClientProvider).updateComicMeta(
        settings,
        comic.comicId,
        {'readed': next},
      );
      _refreshComics();
    } catch (e) {
      _snack('更新失败: $e');
    }
  }

  /// 替换封面：把选中的图片复制到服务端 static 目录并写回 cover_image。
  ///
  /// 目录取服务端返回的 static 绝对路径——桌面端与服务端工作目录不同，
  /// 靠客户端自身路径推导必然落到错误位置。
  Future<void> _replaceCover(ComixComic comic) async {
    final staticDir = ref
        .read(opsOverviewControllerProvider)
        .overview
        ?.service
        .staticDir;
    if (staticDir == null || staticDir.isEmpty) {
      _snack('尚未获取到服务端 static 目录（请先刷新仪表盘）');
      return;
    }

    final comicDir = p.join(staticDir, 'comics', '${comic.comicId}');
    final String? pickedPath;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        initialDirectory: Directory(comicDir).existsSync() ? comicDir : null,
      );
      pickedPath = result?.files.firstOrNull?.path;
    } catch (e) {
      _snack('选择封面图片失败: $e');
      return;
    }
    if (pickedPath == null) return;

    final coverFileName = 'cover${p.extension(pickedPath)}';
    final targetDir = p.join(comicDir, 'cover');
    final relativePath = p
        .join('comics', '${comic.comicId}', 'cover', coverFileName)
        .replaceAll('\\', '/');

    try {
      final dir = Directory(targetDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await File(pickedPath).copy(p.join(targetDir, coverFileName));

      final settings = ref.read(opsSettingsControllerProvider);
      await ref.read(comixApiClientProvider).updateComicMeta(
        settings,
        comic.comicId,
        {'cover_image': relativePath},
      );
      _refreshComics();
      _snack('封面已更新');
    } catch (e) {
      _snack('封面替换失败: $e');
    }
  }

  Future<void> _delete(ComixComic comic) async {
    final confirmed = await showDeleteComicConfirmDialog(context, comic);
    if (confirmed != true || !mounted) return;

    // 同步删除：大漫画的文件清理可能耗时，用不可关闭的遮罩给出反馈。
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
          .deleteComic(settings, comic.comicId);
      if (rootNavigator.canPop()) rootNavigator.pop();
      ref.invalidate(comixComicsProvider);

      final data = result['data'];
      if (data is Map<String, dynamic> && data['files_removed'] == false) {
        _snack('记录已删除，文件清理失败，残留目录：${data['leftover_path'] ?? '未知'}');
      } else {
        _snack('「${comic.title}」已删除');
      }
    } catch (e) {
      if (rootNavigator.canPop()) rootNavigator.pop();
      // 删除失败也要刷新：服务端可能已部分完成（如 DB 已删、文件残留）
      ref.invalidate(comixComicsProvider);
      _snack('删除失败: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final comics = ref.watch(comixComicsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(),
        const SizedBox(height: AppDimens.spacingS),
        Expanded(
          child: comics.when(
            data: (list) {
              final filtered = _applyFilter(list);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(list.isEmpty ? '暂无已登记漫画' : '没有匹配「$_keyword」的漫画'),
                );
              }
              // 列数由可用宽度决定：固定 4 列在宽屏上会把封面卡片拉到失真。
              return GridView.builder(
                padding: const EdgeInsets.all(AppDimens.paddingL),
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: AppDimens.spacingM,
                  mainAxisSpacing: AppDimens.spacingM,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final comic = filtered[index];
                  return _ComicCard(
                    key: ValueKey(comic.comicId),
                    comic: comic,
                    onDownload: () => _download(comic),
                    onUpdateCheck: () => _updateCheck(
                      comicId: comic.comicId,
                      title: comic.title,
                    ),
                    onChapters: () => _chapters(comic),
                    onReplaceCover: () => _replaceCover(comic),
                    onTogglePublic: () => _togglePublic(comic),
                    onToggleReaded: () => _toggleReaded(comic),
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
                  Text('漫画库加载失败: $e'),
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

  List<ComixComic> _applyFilter(List<ComixComic> list) {
    if (_keyword.isEmpty) return list;
    final keyword = _keyword.toLowerCase();
    return list
        .where(
          (c) =>
              c.title.toLowerCase().contains(keyword) ||
              c.siteName.toLowerCase().contains(keyword) ||
              '${c.comicId}' == keyword,
        )
        .toList(growable: false);
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.paddingL,
        AppDimens.paddingM,
        AppDimens.paddingL,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppDimens.spacingM,
            runSpacing: AppDimens.spacingS,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: '搜索标题 / 站点 / ID',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _keyword.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清除',
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _keyword = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _keyword = value.trim()),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _updateCheck(all: true),
                icon: const Icon(Icons.update_rounded, size: 18),
                label: const Text('全站追更检查'),
              ),
              OutlinedButton.icon(
                onPressed: _clean,
                icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                label: const Text('孤儿回收'),
              ),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(comixComicsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('刷新'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComicCard extends StatelessWidget {
  final ComixComic comic;
  final VoidCallback onDownload;
  final VoidCallback onUpdateCheck;
  final VoidCallback onChapters;
  final VoidCallback onReplaceCover;
  final VoidCallback onTogglePublic;
  final VoidCallback onToggleReaded;
  final VoidCallback onDelete;

  const _ComicCard({
    super.key,
    required this.comic,
    required this.onDownload,
    required this.onUpdateCheck,
    required this.onChapters,
    required this.onReplaceCover,
    required this.onTogglePublic,
    required this.onToggleReaded,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildCover(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
            child: Text(
              comic.title,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Wrap(
              spacing: 3,
              runSpacing: 2,
              children: [
                _CompactChip(label: '${comic.chapterCount}章'),
                _CompactChip(label: '${comic.imageCount}图'),
                _CompactChip(
                  label: '${comic.downloaded}/${comic.totalChapters}',
                  color: comic.pending > 0
                      ? Colors.orange
                      : Colors.greenAccent.shade400,
                ),
                if (comic.failed > 0)
                  _CompactChip(
                    label: '失败${comic.failed}',
                    color: Colors.redAccent,
                  ),
                _CompactChip(
                  label: comic.isPublic ? '公开' : '隐藏',
                  color: comic.isPublic ? Colors.green : Colors.orange,
                ),
                if (comic.readed)
                  const _CompactChip(label: '已读', color: Colors.blue),
                if (comic.isLegacy)
                  const _CompactChip(label: 'legacy', color: Colors.blueGrey),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MiniIconButton(
                tooltip: '增量下载',
                onPressed: onDownload,
                icon: Icons.download_rounded,
              ),
              _MiniIconButton(
                tooltip: comic.isLegacy ? 'legacy 资源不参与追更' : '追更检查',
                onPressed: comic.isLegacy ? null : onUpdateCheck,
                icon: Icons.update_rounded,
              ),
              _MiniIconButton(
                tooltip: '替换封面',
                onPressed: onReplaceCover,
                icon: Icons.photo_library_outlined,
              ),
              _MiniIconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: Icons.delete_outline,
                color: Colors.red,
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                padding: EdgeInsets.zero,
                iconSize: 16,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'chapters', child: Text('查看章节')),
                  PopupMenuItem(value: 'public', child: Text('公开 / 隐藏')),
                  PopupMenuItem(value: 'readed', child: Text('标记已读 / 未读')),
                ],
                onSelected: (value) => switch (value) {
                  'chapters' => onChapters(),
                  'public' => onTogglePublic(),
                  'readed' => onToggleReaded(),
                  _ => null,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context) {
    // 本地封面走服务端静态资源；无本地封面时回退到站点原始地址。
    final base = _staticBase(context);
    final url = comic.coverImage.isNotEmpty
        ? '$base${comic.coverImage}'
        : comic.coverUrl;

    return InkWell(
      onTap: onChapters,
      child: url.isEmpty
          ? _coverPlaceholder(Icons.image_not_supported_outlined)
          : Image.network(
              url,
              fit: BoxFit.cover,
              // 自签证书由 CertTrust 的全局 HttpOverrides 处理；
              // 单张封面失败不应让整个网格报错。
              errorBuilder: (_, __, ___) =>
                  _coverPlaceholder(Icons.broken_image_outlined),
            ),
    );
  }

  String _staticBase(BuildContext context) {
    final base = normalizeBaseUrl(
      ProviderScope.containerOf(
        context,
      ).read(opsSettingsControllerProvider).apiBaseUrl,
    );
    return '$base/static/';
  }

  Widget _coverPlaceholder(IconData icon) {
    return Container(
      color: AppColors.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color? color;

  const _MiniIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: color),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      padding: EdgeInsets.zero,
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _CompactChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: effectiveColor)),
    );
  }
}
