import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/shared/image_widget/common_image_widget.dart';
import 'package:torrid/shared/modals/confirm_modal.dart';

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
            child: CommonImageWidget(imageUrl: info.coverImage, isLocal: isLocal,),
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
                    // TODO: 操作过程共加载反馈.
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
                                content: "将下载本漫画到本地目录，方便离线阅读.",
                                confirmFunc: () {},
                              );
                              if (confirm == null || confirm == false) return;
                              try {
                                await ref
                                    .read(comicServiceProvider.notifier)
                                    .downloadAndSaveComic(comicInfo: info);
                                if (context.mounted) {
                                  context.pop();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("下载失败：$e")),
                                  );
                                }
                              }
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
