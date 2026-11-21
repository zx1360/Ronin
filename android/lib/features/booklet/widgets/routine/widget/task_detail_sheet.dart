import 'package:flutter/material.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/core/widgets/file_img_builder/file_img_builder.dart';

// 双击任务查看任务详情
void showTaskDetails(BuildContext context, Task task) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (context) {
      // 定义本弹出页的最大高度和最小宽度.
      final maxHeight = MediaQuery.of(context).size.height * 0.85;
      final minWidth = MediaQuery.of(context).size.width;
      return Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: maxHeight, minWidth: minWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.image.isNotEmpty)
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight * 0.7),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: FileImageBuilder(
                          relativeImagePath: task.image,
                          isOriginScale: true,
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.brown[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.brown[700]),
              ),
            ],
          ),
        ),
      );
    },
  );
}
