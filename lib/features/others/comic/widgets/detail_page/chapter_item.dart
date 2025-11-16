import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/chapter_info.dart';

class ChapterItem extends StatelessWidget {
  final ChapterInfo;
  const ChapterItem({super.key, required this.ChapterInfo});

  @override
  Widget build(BuildContext context) {return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // 根据切换按钮的状态, 选择翻页阅读页面或下拉阅读页面.
      onPressed: () {
        if (_isScrollMode) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComicScrollPage(
                comicName: widget.comicInfo.comicName,
                chapters: _chapters,
                currentChapter: chapter.chapterIndex - 1,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComicReadPage(
                comicName: widget.comicInfo.comicName,
                chapters: _chapters,
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
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );return const Placeholder();
  }
}