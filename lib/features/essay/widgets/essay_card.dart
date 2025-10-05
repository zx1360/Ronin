import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';

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
    // 截断内容，只显示前100个字符
    final previewText = essay.content.length > 100
        ? '${essay.content.substring(0, 100)}...'
        : essay.content;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日期
              Text(
                DateFormat('yyyy年MM月dd日 HH:mm').format(essay.date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 内容预览
              Text(
                previewText,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // 统计信息
              Row(
                children: [
                  Text(
                    '${essay.wordCount} 字',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 12),
                  if (essay.imgs.isNotEmpty)
                    Text(
                      '${essay.imgs.length} 图',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(width: 12),
                  if (essay.labels.isNotEmpty)
                    Text(
                      '${essay.labels.length} 标签',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}