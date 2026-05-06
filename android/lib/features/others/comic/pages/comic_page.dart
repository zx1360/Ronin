import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/core/widgets/async_value_widget/async_value_widget.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/pages/comic_download_tasks_page.dart';
import 'package:torrid/features/others/comic/pages/comic_detail.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';
import 'package:torrid/core/modals/choice_modal.dart';
import 'package:torrid/core/widgets/progress_indicator/progress_indicator.dart';

class ComicPage extends ConsumerStatefulWidget {
  const ComicPage({super.key});

  @override
  ConsumerState<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends ConsumerState<ComicPage> {
  bool isInProgress = false;
  bool isOnlineComicsLoaded = false;
  bool _isHiveInitialized = false;
  bool _showAllComics = false; // false=仅公开, true=全部

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    await HiveService.initComic();
    await ref.read(comicDownloadTasksProvider.notifier).initialize();
    if (mounted) {
      setState(() {
        _isHiveInitialized = true;
      });
    }
  }

  Future<void> initInfos() async {
    final option = await showOptionsDialog(
      context: context,
      title: "初始化漫画文件元数据.",
      content: "初始化方式:",
      options: [
        DialogOption(
          text: "全部重新初始化",
          textColor: Colors.red[300],
          onPressed: () async {
            await ref.read(comicServiceProvider.notifier).refreshInfosAll();
          },
        ),
        DialogOption(
          text: "仅变动更新",
          onPressed: () async {
            await ref.read(comicServiceProvider.notifier).refreshChanged();
          },
        ),
      ],
    );
    if (option == null) {
      return;
    }

    setState(() {
      isInProgress = true;
    });
    await option.onPressed();
    setState(() {
      isInProgress = false;
    });
  }

  Future<void> _syncStatus() async {
    // 收集本地已下载的漫画
    final localComics = ref.read(comicInfosProvider);
    if (localComics.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地没有已下载的漫画')),
        );
      }
      return;
    }

    try {
      // 1. 获取服务器全部漫画数据（强制刷新确保最新）
      ref.invalidate(comicsOnlineProvider);
      final serverComics = await ref.read(comicsOnlineProvider.future);

      final serverComicMap = <String, ComicInfo>{};
      for (final sc in serverComics) {
        serverComicMap[sc.id] = sc;
      }

      int syncedCount = 0;
      int newDownloadCount = 0;

      for (final localComic in localComics) {
        final serverComic = serverComicMap[localComic.id];
        if (serverComic == null) continue;

        // 同步字段到本地
        await ref
            .read(comicServiceProvider.notifier)
            .syncFieldsFromServer(serverComic);
        syncedCount++;

        // 检查是否有新章节
        if (serverComic.chapterCount > localComic.chapterCount) {
          await ref
              .read(comicDownloadTasksProvider.notifier)
              .enqueueComic(comicInfo: localComic);
          newDownloadCount++;
        }
      }

      if (mounted) {
        final msg = newDownloadCount > 0
            ? '已同步 $syncedCount 本漫画，$newDownloadCount 本有更新，已加入下载队列'
            : '已同步 $syncedCount 本漫画，均为最新';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isHiveInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('漫画阅读'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final comicInfos = ref.watch(comicInfosProvider);
    final onlineComicsAsync = isOnlineComicsLoaded
        ? ref.watch(comicsOnlineProvider)
        : null;
    final downloadTasks = ref.watch(comicDownloadTasksProvider);
    final activeDownloadTaskCount = downloadTasks
        .where((task) => task.hasActiveWork)
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
                  await initInfos();
                case 'sync_status':
                  await _syncStatus();
                case 'toggle_visibility':
                  setState(() {
                    _showAllComics = !_showAllComics;
                  });
                  // 刷新在线列表以应用过滤
                  if (isOnlineComicsLoaded) {
                    ref.invalidate(comicsOnlineProvider);
                  }
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
                  subtitle: Text(activeDownloadTaskCount > 0
                      ? '$activeDownloadTaskCount 个进行中'
                      : '暂无进行中的下载'),
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
                  title: Text(_showAllComics ? '显示全部漫画' : '仅显示公开漫画'),
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
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (comicInfos.isEmpty)
                    const Center(
                      child: Text('未找到任何漫画', style: TextStyle(fontSize: 18)),
                    ),
                  if (comicInfos.isNotEmpty) ...[
                    // 修改：优化本地漫画标题样式 - 简约美观
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: BoxBorder.fromLTRB(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        "本地漫画",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    // 本地漫画网格：shrinkWrap=true 提前计算尺寸占据最小高度(但不渲染)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: comicInfos.length,
                      itemBuilder: (context, index) {
                        final comic = comicInfos[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ComicDetailPage(
                                  comicInfo: comic,
                                  isLocal: true,
                                ),
                              ),
                            );
                          },
                          child: ComicItem(comicInfo: comic, isLocal: true),
                        );
                      },
                    ),
                  ],
                  // 在线漫画相关
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: BoxBorder.fromLTRB(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "在线漫画",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        // 加载在线漫画按钮
                        TextButton(
                          onPressed: () {
                            setState(() {
                              isOnlineComicsLoaded = true;
                            });
                            ref.invalidate(comicsOnlineProvider);
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(80, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            backgroundColor: Colors.blue[50],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            "加载",
                            style: TextStyle(
                              color: Color(0xFF0066CC),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 在线漫画列表
                  if (isOnlineComicsLoaded && onlineComicsAsync != null)
                    AsyncValueWidget(
                      asyncValue: onlineComicsAsync,
                      dataBuilder: (comics) {
                        final filtered = _showAllComics
                            ? comics
                            : comics.where((c) => c.isPublic ?? true).toList();
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(10),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final comic = filtered[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ComicDetailPage(
                                      comicInfo: comic,
                                      isLocal: false,
                                    ),
                                  ),
                                );
                              },
                              child: ComicItem(
                                comicInfo: comic,
                                isLocal: false,
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
