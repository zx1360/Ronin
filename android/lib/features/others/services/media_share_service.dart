import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/cache_service.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';

const _shareChannel = MethodChannel('torrid/media_share');

Future<void> shareMedia(
  ApiClient client,
  MediaAsset asset, {
  required CancelToken cancelToken,
  ProgressCallback? onProgress,
}) async {
  Directory? work;
  var shared = false;
  try {
    await CacheService().clearTempCache();
    final root = await IoService.temporaryDirectory('media_share');
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    work = await root.createTemp('share-');
    final name = asset.filePath.split(RegExp(r'[/\\]')).last;
    final file = File(
      path.join(
        work.path,
        name.isEmpty || name == '.' || name == '..' ? 'media' : name,
      ),
    );
    await client.download(
      '/API/gallery/${asset.id}/file',
      file.path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
    );
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    if (await file.length() == 0) throw const FormatException('媒体文件为空');
    await _shareChannel.invokeMethod<void>('shareFile', {
      'path': file.path,
      'mimeType': asset.mimeType,
    });
    shared = true;
  } catch (error) {
    throw ApiClient.mapError(error);
  } finally {
    if (!shared && work != null && await work.exists()) {
      await work.delete(recursive: true);
    }
  }
}
