import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

class GalleryPreview {
  final String? path;
  final double aspectRatio;

  const GalleryPreview({this.path, this.aspectRatio = 1});
}

/// 仅在总览页存活期间缓存文件头，尺寸计算不触发图片解码。
class GalleryPreviewCatalog {
  final _cache = <(String?, String?), GalleryPreview>{};

  Future<Map<String, GalleryPreview>> load(
    List<MediaAsset> assets,
    GalleryStorageService storage,
  ) async {
    final previewRoot = await storage.getLocalPreviewPath('');
    final thumbRoot = await storage.getLocalThumbPath('');
    final missing = <(String?, String?)>{
      for (final asset in assets)
        if (!_cache.containsKey((asset.previewPath, asset.thumbPath)))
          (asset.previewPath, asset.thumbPath),
    };
    if (missing.isNotEmpty) {
      _cache.addAll(
        await compute(_readPreviews, (
          previewRoot: previewRoot,
          thumbRoot: thumbRoot,
          paths: missing.toList(),
        )),
      );
    }
    return {
      for (final asset in assets)
        asset.id: _cache[(asset.previewPath, asset.thumbPath)]!,
    };
  }
}

Map<(String?, String?), GalleryPreview> _readPreviews(
  ({String previewRoot, String thumbRoot, List<(String?, String?)> paths})
  input,
) {
  final result = <(String?, String?), GalleryPreview>{};
  for (final paths in input.paths) {
    var preview = const GalleryPreview();
    for (final candidate in [
      (input.previewRoot, paths.$1),
      (input.thumbRoot, paths.$2),
    ]) {
      if (candidate.$2 == null) continue;
      final file = File(
        p.join(candidate.$1, candidate.$2!.replaceAll('\\', '/')),
      );
      try {
        if (!file.existsSync()) continue;
        final size = ImageSizeGetter.getSizeResult(FileInput(file)).size;
        if (size.width <= 0 || size.height <= 0) continue;
        preview = GalleryPreview(
          path: file.path,
          aspectRatio: size.needRotate
              ? size.height / size.width
              : size.width / size.height,
        );
        break;
      } catch (_) {
        // 损坏的预览图继续回退到缩略图。
      }
    }
    result[paths] = preview;
  }
  return result;
}
