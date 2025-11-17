import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/services/comic_servic.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/comic_header.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/continue_read_btn.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/row_info_widget.dart';
import 'comic_read_flip.dart';
import 'comic_read_scroll.dart';

class ComicDetailPage extends ConsumerWidget {
  final ComicInfo comicInfo;
  const ComicDetailPage({super.key, required this.comicInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.read(
      chaptersWithComicIdProvider(comicId: comicInfo.id),
    );
    final comicPref=ref.watch(comicPrefWithComicIdProvider(comicId: comicInfo.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(comicInfo.comicName, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 漫画封面和基本信息
            ComicHeader(info: comicInfo),

            // 阅读选项
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ContinueReadingButton(comicInfo: comicInfo,),
                  RowInfoWidget(comicId: comicInfo.id),
                ],
              ),
            ),

            // 章节列表
            if (chapters.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('未找到任何章节'),
                ),
              ),

            // 使用GridView实现等高等宽的章节按钮
            if (chapters.isNotEmpty)
              GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5, // 适当调整比例使按钮等高等宽且美观
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  // 单个章节按钮.
                  // TODO: 也许分离呢? 但是有需要依赖comicInfo, 参数要传很多份. 或者传context到contentProvider.notifier来解决.
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
                    // 根据切换按钮的状态, 选择翻页阅读页面或下拉阅读页面.
                    onPressed: () {
                      final isScrollMode=comicPref.flipReading;
                      if (isScrollMode) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ComicScrollPage(
                              comicName: comicInfo.comicName,
                              chapters: chapters,
                              currentChapter: chapter.chapterIndex - 1,
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ComicReadPage(
                              comicName: comicInfo.comicName,
                              chapters: chapters,
                              currentChapter: chapter.chapterIndex - 1,
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
                },
              ),
          ],
        ),
      ),
    );
  }
}
