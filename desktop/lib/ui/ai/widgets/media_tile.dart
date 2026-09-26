import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:northstar/app/theme.dart';
import 'package:northstar/core/providers/gallery/gallery_providers.dart';
import 'package:northstar/core/providers/ops/ops_overview_provider.dart';
import 'package:northstar/infrastructure/ops/file_reveal_service.dart';

/// 媒体缩略图卡片：点击选择，右下角按钮打开所在目录。
class AiMediaTile extends StatelessWidget {
  const AiMediaTile({
    super.key,
    required this.thumbUrl,
    required this.fileName,
    required this.selected,
    required this.onTap,
    this.onReveal,
    this.size = 104,
  });

  final String thumbUrl;
  final String fileName;
  final bool selected;
  final VoidCallback onTap;

  /// 为空表示不提供「打开所在目录」。
  final VoidCallback? onReveal;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
                    child: Image.network(
                      thumbUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: AppColors.surfaceVariant,
                        child: Icon(Icons.broken_image_outlined, size: 20),
                      ),
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 2,
                    left: 2,
                    child: Icon(Icons.check_circle,
                        size: 18, color: AppColors.primary),
                  ),
                if (onReveal != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      onPressed: onReveal,
                      tooltip: '打开所在目录',
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(26, 26),
                        padding: EdgeInsets.zero,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(6),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.folder_open_rounded),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// 打开媒体文件所在目录并选中它（失败时如实提示）。
///
/// 绝对路径来自服务端 `/API/ops/overview` 的 gallery 目录；尚未取到时主动刷新一次，
/// 不猜测路径——猜错就会打开无关目录。
Future<void> revealMediaFile(
  BuildContext context,
  WidgetRef ref,
  String filePath,
) async {
  var root = ref.read(galleryMediaRootProvider);
  if (root == null || root.isEmpty) {
    await ref.read(opsOverviewControllerProvider.notifier).refresh();
    root = ref.read(galleryMediaRootProvider);
  }

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final absolute = resolveMediaPath(root, filePath);
  if (absolute == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('未获取到服务端媒体目录，请稍后重试')),
    );
    return;
  }

  final error = await FileRevealService.reveal(absolute);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}
