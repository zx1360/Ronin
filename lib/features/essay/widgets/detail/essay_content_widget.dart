import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:torrid/app/theme_book.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/features/essay/providers/setting_provider.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/detail/check_image_sheet.dart';
import 'package:torrid/shared/modals/confirm_modal.dart';
import 'package:torrid/shared/utils/util.dart';
import 'package:torrid/shared/widgets/file_img_builder.dart';

class EssayContentWidget extends ConsumerWidget {
  const EssayContentWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');

    // 内容数据
    final essay = ref.watch(contentServerProvider)!;
    final idMap = ref.watch(idMapProvider);
    final labelNames = essay.labels.map((l) => idMap[l]!);

    // 对于当天的随笔提供删除功能.
    final isToday = isSameDay(essay.date, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日期和字数, 赋值文本内容按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dateFormat.format(essay.date),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            Row(
              children: [
                Text(
                  '${essay.wordCount} 字',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
                // 复制文本按钮.
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: essay.content));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("已复制随笔内容.")));
                  },
                  icon: Icon(Icons.copy),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 标签
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
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
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (isToday)
              IconButton(
                onPressed: () => showConfirmDialog(
                  context: context,
                  title: "确认删除",
                  content: "删除后随笔将无法恢复, 是否继续?",
                  confirmFunc: () async {
                    await ref
                        .read(essayServiceProvider.notifier)
                        .deleteEssay(essay);
                    if(context.mounted){
                      context.pop();
                    }
                  },
                ),
                icon: Icon(
                  IconData(0xe649, fontFamily: "iconfont"),
                  color: AppTheme.outline,
                ),
                padding: EdgeInsets.zero,
                splashRadius: 16,
                tooltip: "删除随笔(当天可用)",
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 是否展示可编辑.

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
                    onDoubleTap: () =>
                        showBigScaledImage(context, essay.imgs[index]),
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
                      DateFormat(
                        'yyyy年-MM月dd日 HH:mm',
                      ).format(message.timestamp),
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
                        style: theme.textTheme.bodyMedium,
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
