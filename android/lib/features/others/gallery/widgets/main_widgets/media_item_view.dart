import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/image_edit.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/network_image_widget.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/video_player_widget.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 单个媒体项视图 (图片/视频)
/// 根据媒体类型自动选择合适的展示方式
class MediaItemView extends ConsumerWidget {
  final MediaAsset asset;
  final int rotationQuarterTurns;
  final ValueChanged<double>? onAspectRatio;

  const MediaItemView({
    super.key,
    required this.asset,
    this.rotationQuarterTurns = 0,
    this.onAspectRatio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(galleryStorageProvider);
    final filesRevision = ref.watch(galleryFilesRevisionProvider);
    final apiClient = ref.watch(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    final editedTurns = ImageEdit.parse(asset.editParams).quarterTurns;
    void reportAspect(double ratio) {
      onAspectRatio?.call(editedTurns.isOdd ? 1 / ratio : ratio);
    }

    final effectiveTurns = (rotationQuarterTurns + editedTurns) % 4;

    if (asset.isImage) {
      final imageUrl = galleryMediaUrl(baseUrl, asset);
      return NetworkImageWidget(
        key: ValueKey((asset.id, filesRevision)),
        imageUrl: imageUrl,
        asset: asset,
        storage: storage,
        rotationQuarterTurns: effectiveTurns,
        httpHeaders: headers,
        onAspectRatio: reportAspect,
      );
    }

    if (asset.isVideo) {
      return VideoPlayerWidget(
        key: ValueKey((asset.id, filesRevision, baseUrl)),
        asset: asset,
        storage: storage,
        rotationQuarterTurns: effectiveTurns,
        onAspectRatio: reportAspect,
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Icon(Icons.insert_drive_file, color: Colors.grey, size: 64),
      ),
    );
  }
}
