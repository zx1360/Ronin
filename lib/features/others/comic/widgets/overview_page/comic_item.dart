import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/shared/image_widget/common_image_widget.dart';

class ComicItem extends ConsumerWidget {
  final ComicInfo comicInfo;
  const ComicItem({super.key, required this.comicInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 漫画封面
          Expanded(child: CommonImageWidget(imageUrl: comicInfo.coverImage)),
          const SizedBox(height: 5),
          // 漫画标题（自动换行）
          Text(
            comicInfo.comicName,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // 章节数
          Text(
            '${comicInfo.chapterCount} 章',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      );
  }
}
