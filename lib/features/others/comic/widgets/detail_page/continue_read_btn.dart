import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/pages/comic_read_scroll.dart';
import 'package:torrid/features/others/comic/provider/content_provider.dart';
import 'package:torrid/features/todo/providers/content_provider.dart';

/// 漫画详情页 - 继续阅读按钮组件
class ContinueReadingButton extends ConsumerWidget {
  const ContinueReadingButton({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content=ref.watch(comicContentProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
          final targetChapter = progress?.chapterIndex ?? 0;
          Navigator.push(
            context,
            MaterialPageRoute(
              // TODO: 两种方式(读取shared_preference).
              builder: (_) => ComicScrollPage(
                chapters: chapters as List<ChapterInfo>,
                currentChapter: targetChapter,
                comicName: comicName,
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
            Text(
              progress != null ? '继续阅读' : '开始阅读',
            ),
            const SizedBox(height: 4),

            // 进度提示（有进度时展示）
            if (progress != null)
              Text(
                '第${progress.chapterIndex + 1}章 第${progress.pageIndex + 1}页',
              ),
          ],
        ),
      ),
    );
  }
}