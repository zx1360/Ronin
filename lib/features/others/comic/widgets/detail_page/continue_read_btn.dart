import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/pages/comic_read_scroll.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';

/// 漫画详情页 - 继续阅读按钮组件
class ContinueReadingButton extends ConsumerWidget {
  final ComicInfo comicInfo;
  const ContinueReadingButton({super.key, required this.comicInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapterInfos = ref.read(chaptersWithComicIdProvider(comicId: comicInfo.id));
    final comicPref = ref.watch(comicPrefWithComicIdProvider(comicId: comicInfo.id));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
          final targetChapter = comicPref.chapterIndex;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComicScrollPage(
                chapters: chapterInfos,
                currentChapter: targetChapter,
                comicName: comicInfo.comicName,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 按钮文本
            Text(comicPref.chapterIndex != 0 ? '继续阅读' : '开始阅读'),
            const SizedBox(height: 4),

            // 进度提示（有进度时展示）
            if (comicPref.chapterIndex != 0)
              Text(
                '第${comicPref.chapterIndex + 1}章 第${comicPref.pageIndex + 1}页',
              ),
          ],
        ),
      ),
    );
  }
}
