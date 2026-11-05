import 'package:flutter/material.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/immich/widgets/immich_ops_sheet.dart';
import 'package:torrid/features/others/widgets/media_viewer_page.dart';

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
          IconButton(
            icon: const Icon(Icons.image_search),
            tooltip: '以图搜图',
            onPressed: () {
              Navigator.of(viewerContext).pop();
              onSimilar(asset);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '详情与标签',
            onPressed: () => showImmichMediaDetail(
              viewerContext,
              mediaId: asset.id,
              fallback: asset,
            ),
          ),
        ],
      ),
    ),
  );
}
