import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/storage/cache_service.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';

const _shareChannel = MethodChannel('torrid/media_share');

Future<void> shareMedia(
  ApiClient client,
  MediaAsset asset, {
  required CancelToken cancelToken,
  ProgressCallback? onProgress,
}) async {
  await shareMediaBatch(
    client,
    [asset],
    cancelToken: cancelToken,
    onProgress: (current, total, fraction) =>
        onProgress?.call((fraction * 1000).round(), 1000),
  );
}

Future<void> shareMediaBatch(
  ApiClient client,
  List<MediaAsset> assets, {
  required CancelToken cancelToken,
  void Function(int current, int total, double fraction)? onProgress,
}) async {
  final unique = {for (final asset in assets) asset.id: asset}.values.toList();
  if (unique.isEmpty) throw const FormatException('未选择可分享的文件');
  Directory? work;
  var shared = false;
  try {
    await CacheService().clearTempCache();
    final root = await IoService.temporaryDirectory('media_share');
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    work = await root.createTemp('share-');
    final files = <Map<String, String?>>[];
    for (var i = 0; i < unique.length; i++) {
      final asset = unique[i];
      final name = path.basename(asset.filePath.replaceAll('\\', '/'));
      final safeName = name.isEmpty || name == '.' || name == '..'
          ? 'media'
          : name;
      final file = File(
        path.join(
          work.path,
          unique.length == 1 ? safeName : '${i + 1}_$safeName',
        ),
      );
      onProgress?.call(i + 1, unique.length, 0);
      await client.download(
        '/API/gallery/${asset.id}/file',
        file.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) => onProgress?.call(
          i + 1,
          unique.length,
          total > 0 ? (received / total).clamp(0.0, 1.0) : 0,
        ),
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      if (await file.length() == 0) throw FormatException('文件为空：$safeName');
      files.add({'path': file.path, 'mimeType': asset.mimeType});
      onProgress?.call(i + 1, unique.length, 1);
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    await _shareChannel.invokeMethod<void>('shareFiles', {'files': files});
    shared = true;
  } catch (error) {
    throw ApiClient.mapError(error);
  } finally {
    if (!shared && work != null && await work.exists()) {
      try {
        await work.delete(recursive: true);
      } on FileSystemException catch (error) {
        AppLogger().warning('分享暂存文件稍后清理：$error');
      }
    }
  }
}

Future<void> showMediaShareDialog(
  BuildContext context,
  ApiClient client,
  List<MediaAsset> assets,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _MediaShareDialog(client: client, assets: List.of(assets)),
);

class _MediaShareDialog extends StatefulWidget {
  final ApiClient client;
  final List<MediaAsset> assets;
  const _MediaShareDialog({required this.client, required this.assets});
  @override
  State<_MediaShareDialog> createState() => _MediaShareDialogState();
}

class _MediaShareDialogState extends State<_MediaShareDialog> {
  final _cancel = CancelToken();
  int _current = 0, _total = 0;
  double _fraction = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await shareMediaBatch(
        widget.client,
        widget.assets,
        cancelToken: _cancel,
        onProgress: (current, total, fraction) {
          if (mounted) {
            setState(() {
              _current = current;
              _total = total;
              _fraction = fraction;
            });
          }
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted && !_cancel.isCancelled) {
        setState(() => _error = error.toString());
      }
    }
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _cancel.cancel();
    },
    child: AlertDialog(
      title: Text(_error == null ? '准备分享 $_current / $_total' : '分享失败'),
      content: _error == null
          ? LinearProgressIndicator(
              value: _total > 0
                  ? ((_current - 1 + _fraction) / _total).clamp(0.0, 1.0)
                  : null,
            )
          : Text('$_error\n已保留所选文件，请稍后重试。'),
      actions: [
        TextButton(
          onPressed: () {
            _cancel.cancel();
            Navigator.pop(context);
          },
          child: Text(_error == null ? '取消' : '关闭'),
        ),
      ],
    ),
  );
}
