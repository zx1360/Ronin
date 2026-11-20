import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/confirm_modal.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/pages/comic_download_tasks_page.dart';
import 'package:torrid/features/others/comic/pages/comic_detail.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';
import 'package:torrid/core/widgets/progress_indicator/progress_indicator.dart';

class ComicPage extends ConsumerStatefulWidget {
  const ComicPage({super.key});

  @override
  ConsumerState<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends ConsumerState<ComicPage> {
  bool isInProgress = false;
  bool isOnlineComicsLoaded = false;
  bool _showAllComics = false; // false=仅公开, true=全部

  Future<void> _refreshLocalCatalog() async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: '重新扫描本地漫画？',
      content: '扫描后，已找不到文件的漫画会从本地书库移除，其阅读进度也会清除。',
      confirmFunc: () {},
    );
    if (confirmed != true || !mounted) return;

    setState(() => isInProgress = true);
    try {
      await ref.read(comicServiceProvider.notifier).refreshInfosAll();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('扫描本地漫画失败：$error')));
      }
    } finally {
      if (mounted) setState(() => isInProgress = false);
    }
  }

  /// 与服务端同步本地漫画状态；编排在 [ComicService.syncWithServer] 里。
  Future<void> _syncStatus() async {
    try {
      final result = await ref
          .read(comicServiceProvider.notifier)
          .syncWithServer();
      if (!mounted) return;

      final message = result.hasLocalComics ? result.message : '本地没有已下载的漫画';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('同步失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final comicInfos = ref.watch(comicInfosProvider);
    final onlineComicsAsync = isOnlineComicsLoaded
        ? ref.watch(comicsOnlineProvider)
        : null;
    final downloadTasks = ref.watch(comicDownloadTasksProvider);
    final activeDownloadTaskCount = downloadTasks
        .where((task) => !task.isTerminal)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画阅读'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '更多操作',
            onSelected: (value) async {
              switch (value) {
                case 'download_tasks':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ComicDownloadTasksPage(),
                    ),
                  );
                case 'refresh_meta':
                  if (!isInProgress) await _refreshLocalCatalog();
                case 'sync_status':
                  await _syncStatus();
                case 'toggle_visibility':
                  setState(() {
                    _showAllComics = !_showAllComics;
                  });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'download_tasks',
                child: ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.downloading_rounded),
                      if (activeDownloadTaskCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              activeDownloadTaskCount > 99
                                  ? '99+'
                                  : '$activeDownloadTaskCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: const Text('下载任务'),
                  subtitle: Text(
                    activeDownloadTaskCount > 0
                        ? '$activeDownloadTaskCount 个进行中'
                        : '暂无进行中的下载',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'refresh_meta',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('刷新元数据'),
                  subtitle: Text('重新扫描本地漫画文件'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'sync_status',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('同步状态'),
                  subtitle: Text('检查更新章节并同步后端字段'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'toggle_visibility',
                child: ListTile(
                  leading: Icon(
                    _showAllComics ? Icons.visibility : Icons.visibility_off,
                  ),
                  title: Text(_showAllComics ? '仅显示公开漫画' : '显示全部漫画'),
                  subtitle: Text(_showAllComics ? '当前：全部' : '当前：仅公开'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: isInProgress
          ? ProgressIndicatorWidget()
          : CustomScrollView(
              slivers: [
                _sectionHeader('本地漫画'),
                _comicGrid(comicInfos, isLocal: true),
                _sectionHeader(
                  '在线漫画',
                  action: TextButton(
                    onPressed: onlineComicsAsync?.isLoading == true
                        ? null
                        : () {
                            setState(() => isOnlineComicsLoaded = true);
                            ref.invalidate(comicsOnlineProvider);
                          },
                    child: Text(isOnlineComicsLoaded ? '刷新' : '加载'),
                  ),
                ),
                if (onlineComicsAsync != null)
                  onlineComicsAsync.when(
                    data: (comics) => _comicGrid(comics, isLocal: false),
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (error, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('加载在线漫画失败：$error'),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title, {Widget? action}) => SliverToBoxAdapter(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          if (action != null) action,
        ],
      ),
    ),
  );

  Widget _comicGrid(List<ComicInfo> comics, {required bool isLocal}) {
    final visible = _showAllComics
        ? comics
        : comics.where((comic) => comic.isPublic ?? true).toList();
    if (visible.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(child: Text(isLocal ? '暂无本地漫画' : '暂无在线漫画')),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final comic = visible[index];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ComicDetailPage(comicInfo: comic, isLocal: isLocal),
              ),
            ),
            child: ComicItem(comicInfo: comic, isLocal: isLocal),
          );
        },
      ),
    );
  }
}
