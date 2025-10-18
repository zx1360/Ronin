import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/detail/check_image_sheet.dart';
import 'package:torrid/shared/widgets/file_img_builder.dart';

class EssayContentWidget extends ConsumerWidget {
  final Essay essay;
  const EssayContentWidget({super.key, required this.essay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idMap = ref.watch(idMapProvider);
    final labelNames = essay.labels.map((l)=>idMap[l]!);
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期和字数
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateFormat.format(essay.date),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            Text(
              '${essay.wordCount} 字',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 标签
        if (labelNames.isNotEmpty)
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: labelNames
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

        const SizedBox(height: 20),

        // 内容
        Text(
          essay.content,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(height: 1.8, letterSpacing: 0.3),
          textAlign: TextAlign.justify,
        ),

        const SizedBox(height: 24),

        // 图片
        if (essay.imgs.isNotEmpty)
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: 1.0,
                ),
                itemCount: essay.imgs.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onDoubleTap: () => showBigScaledImage(context, essay.imgs[index]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: FileImageBuilder(
                        relativeImagePath: essay.imgs[index],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),

        // 留言区标题
        Text(
          '留言',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Divider(height: 24),

        // 留言列表
        if (essay.messages.isEmpty)
          Text(
            '暂无留言',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: essay.messages.length,
            itemBuilder: (context, index) {
              final message = essay.messages[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy年-MM月dd日 HH:mm').format(message.timestamp),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        message.content,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
