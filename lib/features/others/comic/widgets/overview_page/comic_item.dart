import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/data_class.dart';
import 'package:torrid/features/others/comic/pages/comic_detail.dart';

class ComicItem extends StatelessWidget {
  final ComicInfo comic;
  const ComicItem({super.key, required this.comic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComicDetailPage(comicInfo: comic),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 漫画封面
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: comic.coverImage != null
                  ? Image.file(
                      File(comic.coverImage!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),
          ),
          const SizedBox(height: 5),
          // 漫画标题（自动换行）
          Text(
            comic.name,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // 章节数
          Text(
            '${comic.chapterCount} 章',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 封面占位符
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.book, color: Colors.grey, size: 30),
      ),
    );
  }
}
