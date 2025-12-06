import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/pages/comic_detail.dart';
import 'package:torrid/features/others/comic/pages/comic_detail_online.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';
import 'package:torrid/shared/modals/choice_modal.dart';
import 'package:torrid/shared/modals/dialog_option.dart';
import 'package:torrid/shared/widgets/progress_indicator.dart';

class ComicPage extends ConsumerStatefulWidget {
  const ComicPage({super.key});

  @override
  ConsumerState<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends ConsumerState<ComicPage> {
  bool isLoading = false;

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
      isLoading = true;
    });
    await option.onPressed();
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final comicInfos = ref.watch(comicInfosProvider);
    final onlineComicsAsync = ref.watch(comicsOnlineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画阅读'),
        centerTitle: true,
        actions: [IconButton(onPressed: initInfos, icon: Icon(Icons.refresh))],
      ),
      body: isLoading
          ? ProgressIndicatorWidget()
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (comicInfos.isEmpty)
                    const Center(
                      child: Text('未找到任何漫画', style: TextStyle(fontSize: 18)),
                    ),
                  if (comicInfos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text("本地漫画", style: TextStyle(fontSize: 18)),
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
                                builder: (context) =>
                                    ComicDetailPage(comicInfo: comic),
                              ),
                            );
                          },
                          child: ComicItem(comicInfo: comic),
                        );
                      },
                    ),
                  ],
                  // 在线漫画列表
                  // TODO: 之后统一以下数据格式, 本地的comicId/chapterId与服务端一致, 然后此处在线漫画只展示不在本地的,
                  // TODO: 更久之后, 有了'用户'模块, 漫画类别分类, 以及对于用户是否读完分类.
                  // 默认不加载, 点击按钮加载.
                  // TODO:!!! 使用cached_network, 缓存图片.
                  if (!onlineComicsAsync.isLoading)
                    Container(
                      padding: const EdgeInsets.all(10),
                      child: const Text("在线漫画", style: TextStyle(fontSize: 18)),
                    ),
                  onlineComicsAsync.when(
                    data: (comics) => GridView.builder(
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
                      itemCount: comics.length,
                      itemBuilder: (context, index) {
                        final comic = comics[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    OnlineComicDetailPage(comicInfo: comic),
                              ),
                            );
                          },
                          child: ComicItem(comicInfo: comic),
                        );
                      },
                    ),
                    // TODO: 考虑封装一下呢.
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => Center(child: Text('错误：$error')),
                  ),
                ],
              ),
            ),
    );
  }
}
