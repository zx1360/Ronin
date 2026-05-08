import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const MediaItemView({
    super.key,
    required this.asset,
    this.rotationQuarterTurns = 0,
  });

  /// 从 editParams JSON 解析旋转角度并转为 quarterTurns
  int get _editRotationTurns {
    final p = asset.editParams;
    if (p == null) return 0;
    try {
      final json = jsonDecode(p) as Map<String, dynamic>;
      if (json['type'] == 'image') {
        final deg = (json['rotation'] as int? ?? 0) % 360;
        return deg ~/ 90;
      }
    } catch (_) {}
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storage = ref.watch(galleryStorageProvider);
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;

    final effectiveTurns = (rotationQuarterTurns + _editRotationTurns) % 4;

    if (asset.isImage) {
      final imageUrl = '$baseUrl/API/gallery/${asset.id}/file';
      return NetworkImageWidget(
        key: ValueKey('image_${asset.id}_$effectiveTurns'),
        imageUrl: imageUrl,
        asset: asset,
        storage: storage,
        rotationQuarterTurns: effectiveTurns,
        httpHeaders: headers,
      );
    }

    if (asset.isVideo) {
      return VideoPlayerWidget(
        key: ValueKey('video_${asset.id}_$effectiveTurns'),
        asset: asset,
        storage: storage,
        rotationQuarterTurns: effectiveTurns,
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
