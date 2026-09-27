import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/download_task_provider.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/widgets/image_widget/common_image_widget.dart';
import 'package:torrid/core/modals/confirm_modal.dart';

class ComicHeader extends ConsumerWidget {
  final ComicInfo info;
  final bool isLocal;
  const ComicHeader({super.key, required this.info, required this.isLocal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          SizedBox(
            width: 120,
            height: 180,
            child: CommonImageWidget(
              imageUrl: info.coverImage,
              isLocal: isLocal,
            ),
          ),

          const SizedBox(width: 16),

          // 漫画信息，使用Expanded避免溢出
          Expanded(
            child: SizedBox(
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.comicName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('章节数', '${info.chapterCount} 章'),
                  _buildInfoRow('总图片数', '${info.imageCount} 张'),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: isLocal
                        ? TextButton.icon(
                            onPressed: () async {
                              final confirm = await showConfirmDialog(
                                context: context,
                                title: "删除漫画",
                                content: "将从本地目录彻底删除本漫画.",
                                confirmFunc: () {},
                              );
                              if (confirm == null || confirm == false) return;
                              await IoService.clearSpecificDirectory(
                                "/comics/${info.comicName}",
                              );
                              await ref
                                  .read(comicServiceProvider.notifier)
                                  .refreshChanged();
                              if (context.mounted) {
                                context.pop();
                              }
                            },
                            label: Text("删除"),
                            icon: Icon(Icons.delete_outline_rounded),
                          )
                        : TextButton.icon(
                            onPressed: () async {
                              final confirm = await showConfirmDialog(
                                context: context,
                                title: "下载漫画",
                                content: "将本漫画加入下载任务，支持后台与中断续传.",
                                confirmFunc: () {},
                              );
                              if (confirm == null || confirm == false) return;
                              final task = await ref
                                  .read(comicDownloadTasksProvider.notifier)
                                  .enqueueComic(comicInfo: info);

                              if (!context.mounted) return;
                              if (task == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("该漫画已有进行中的下载任务"),
                                  ),
                                );
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("已加入下载任务，可返回列表查看进度"),
                                ),
                              );
                            },
                            label: Text("下载"),
                            icon: Icon(Icons.download),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
