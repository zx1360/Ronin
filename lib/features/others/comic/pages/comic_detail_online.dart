import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/online_status_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/comic_header.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/continue_read_btn.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/row_info_widget.dart';
import 'comic_read_flip.dart';
import 'comic_read_scroll.dart';

// TODO: 加入'删除'选项, 从本地删除.
class OnlineComicDetailPage extends ConsumerWidget {
  final ComicInfo comicInfo;
  const OnlineComicDetailPage({super.key, required this.comicInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(
      onlineChaptersWithComicIdProvider(comicId: comicInfo.id),
    );
    final comicPref = ref.watch(
      comicPrefWithComicIdProvider(comicId: comicInfo.id),
    );

    // return Placeholder();

    return Scaffold(
      appBar: AppBar(
        title: Text(comicInfo.comicName, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: ComicHeader(info: comicInfo)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ContinueReadingButton(comicInfo: comicInfo),
                  RowInfoWidget(comicId: comicInfo.id),
                ],
              ),
            ),
          ),
          // 在线章节数据
          chaptersAsync.when(
            data: (chapters) => SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final chapter = chapters[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onPressed: () {
                    final isFlipMode = comicPref.flipReading;
                    if (isFlipMode) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComicReadPage(
                            comicInfo: comicInfo,
                            chapterIndex: index,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ComicScrollPage(
                            comicInfo: comicInfo,
                            chapterIndex: index,
                          ),
                        ),
                      );
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        getChapterTitle(chapter.dirName),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '第 ${chapter.chapterIndex} 章',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${chapter.images.length} 页',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }, childCount: chapters.length),
            ),
            loading: () => SliverToBoxAdapter(child: const Center(child: CircularProgressIndicator()),),
            error: (error, stack) => SliverToBoxAdapter(child: Center(child: Text('错误：$error')),),
          ),
        ],
      ),
    );
  }
}
