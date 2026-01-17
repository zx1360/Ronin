import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/core/widgets/file_img_builder/file_img_builder.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';

class EssayCard extends ConsumerWidget {
  final Essay essay;
  final VoidCallback onTap;

  const EssayCard({super.key, required this.essay, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idMap = ref.watch(idMapProvider);

    final dateFormat = DateFormat('MM月dd日');
    final labelNames = essay.labels.map((l) => idMap[l] ?? "").toList();

    // 内容预览（最多显示3行）
    String previewText = essay.content.replaceAll('\n', ' ');
    if (previewText.length > 100) {
      previewText = '${previewText.substring(0, 100)}...';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期和标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(essay.date),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                if (labelNames.isNotEmpty)
                  Row(
                    children: labelNames
                        .map(
                          (label) => Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // 内容预览
            Text(
              previewText,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 12),

            // 图片预览
            if (essay.imgs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    ...essay.imgs
                        .take(3)
                        .map(
                          (i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: FileImageBuilder(relativeImagePath: i),
                          ),
                        ),
                    if (essay.imgs.length > 3)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '+${essay.imgs.length - 3}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 底部信息
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${essay.wordCount} 字',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                    // 心情显示
                    if (essay.mood != null) ...[                    
                      const SizedBox(width: 12),
                      MoodDisplay(mood: essay.mood, iconSize: 16),
                    ],
                  ],
                ),
                if (essay.messages.isNotEmpty)
                  Text(
                    '${essay.messages.length} 条留言',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
