import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/pages/comic_detail.dart';
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
  bool isInProgress = false;
  // 加载在线漫画
  bool isOnlineComicsLoaded = false;

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

  @override
  Widget build(BuildContext context) {
    final comicInfos = ref.watch(comicInfosProvider);
    final onlineComicsAsync = isOnlineComicsLoaded ? ref.watch(comicsOnlineProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('漫画阅读'),
        centerTitle: true,
        actions: [IconButton(onPressed: initInfos, icon: Icon(Icons.refresh))],
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: BoxBorder.fromLTRB(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
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
                                builder: (context) =>
                                    ComicDetailPage(comicInfo: comic, isLocal: true,),
                              ),
                            );
                          },
                          child: ComicItem(comicInfo: comic, isLocal: true,),
                        );
                      },
                    ),
                  ],
                  // 在线漫画相关
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: BoxBorder.fromLTRB(bottom: BorderSide(color: Colors.grey[200]!, width: 1)),
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
                          onPressed: (){
                            setState(() {
                              isOnlineComicsLoaded = true;
                            });
                            ref.refresh(comicsOnlineProvider);
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
                    onlineComicsAsync.when(
                      data: (comics) {
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
                        itemCount: comics.length,
                        itemBuilder: (context, index) {
                          final comic = comics[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ComicDetailPage(comicInfo: comic, isLocal: false),
                                ),
                              );
                            },
                            child: ComicItem(comicInfo: comic, isLocal: false,),
                          );
                        },
                      );
                      },
                      // TODO: 考虑封装一下呢.
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(child: Text('错误：$error')),
                    ),
                  // 在线漫画相关修改 End
                ],
              ),
            ),
    );
  }
}