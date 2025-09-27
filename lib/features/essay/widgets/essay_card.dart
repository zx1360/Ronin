import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/example_datas.dart';

class EssayCard extends StatelessWidget {
  final Essay essay;
  final VoidCallback onTap;

  const EssayCard({
    super.key,
    required this.essay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MM月dd日');
    final labelNames = essay.labels.map((id) => EssaySampleData.getLabelName(id)).toList();
    
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
              color: Colors.black.withOpacity(0.03),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                if (labelNames.isNotEmpty)
                  Text(
                    labelNames.first,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        essay.imgs[0],
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (essay.imgs.length > 1)
                      Positioned(
                        left: 45,
                        child: Container(
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
                              '+${essay.imgs.length - 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
                Text(
                  '${essay.wordCount} 字',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
                if (essay.messages.isNotEmpty)
                  Text(
                    '${essay.messages.length} 条留言',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
