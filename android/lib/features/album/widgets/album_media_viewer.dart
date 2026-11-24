import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/album/providers/album_providers.dart';
import 'package:torrid/features/album/widgets/album_dialogs.dart';
import 'package:torrid/features/album/widgets/album_ops_sheet.dart';
import 'package:torrid/features/album/widgets/album_related_sheet.dart';
import 'package:torrid/features/gallery/widgets/media_viewer_page.dart';

void openAlbumMediaViewer(
  BuildContext context, {
  required List<MediaAsset> assets,
  required String mediaId,
  required ValueChanged<MediaAsset> onSimilar,
  Map<String, double> scores = const {},
}) {
  final index = assets.indexWhere((asset) => asset.id == mediaId);
  if (index < 0) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MediaViewerPage(
        assets: assets,
        initialIndex: index,
        subtitleBuilder: (asset) {
          final score = scores[asset.id] ?? 0;
          return score > 0 ? '相关度 ${score.toStringAsFixed(3)}' : null;
        },
        actions: (viewerContext, asset) => [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: '问问 AI',
            onPressed: () => askAiAboutMedia(
              viewerContext,
              mediaId: asset.id,
              fileName: asset.filePath.split(RegExp(r'[/\\]')).last,
            ),
          ),
          if (!asset.isDeleted)
            IconButton(
              icon: const Icon(Icons.collections_outlined),
              tooltip: '相关媒体与捆绑',
              onPressed: () => showAlbumRelatedMedia(viewerContext, asset),
            ),
          if (!asset.isDeleted)
            Consumer(
              builder: (context, ref, _) => IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '标记待删除',
                onPressed: ref.watch(albumActionsProvider)
                    ? null
                    : () => _markForDeletion(context, ref, asset),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '详情与标签',
            onPressed: () async {
              final similar = await showAlbumMediaDetail(
                viewerContext,
                fallback: asset,
              );
              if (!viewerContext.mounted || similar == null) return;
              Navigator.of(viewerContext).pop();
              onSimilar(similar);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _markForDeletion(
  BuildContext context,
  WidgetRef ref,
  MediaAsset asset,
) async {
  if (!await confirmAlbumDeletion(context, 1) || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  try {
    await ref.read(albumActionsProvider.notifier).setDeleted([asset.id], true);
    if (route?.isCurrent == true) navigator.pop();
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('已标记待删除，可在「含待删除」中恢复')),
      );
    }
  } catch (error) {
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('操作失败: $error')));
    }
  }
}
