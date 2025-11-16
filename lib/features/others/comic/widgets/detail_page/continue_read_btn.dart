import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';
import 'package:torrid/features/others/comic/pages/comic_read_scroll.dart';
import 'package:torrid/features/others/comic/provider/comic_provider.dart';

/// 漫画详情页 - 继续阅读按钮组件
class ContinueReadingButton extends ConsumerWidget {
  final String comicName; // 当前漫画名
  final List<dynamic> chapters; // 当前漫画章节列表（根据你的ChapterInfo类型调整）

  const ContinueReadingButton({
    super.key,
    required this.comicName,
    required this.chapters,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressNotifier = ref.watch(comicPreferenceProvider.notifier);
    final progress = progressNotifier.getProgress(comicName);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
          // TODO: 后续添加跳转逻辑（打开漫画上次阅读记录）
          // 示例：
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