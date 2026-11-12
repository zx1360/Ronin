import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/widgets/media/media_video_player.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class GalleryVideo extends ConsumerWidget {
  const GalleryVideo({
    super.key,
    required this.asset,
    this.storage,
    this.quarterTurns = 0,
    this.autoPlay = false,
    this.onAspectRatio,
  });

  final MediaAsset asset;
  final GalleryStorageService? storage;
  final int quarterTurns;
  final bool autoPlay;
  final ValueChanged<double>? onAspectRatio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientManagerProvider);
    final storage = this.storage;
    return MediaVideoPlayer(
      uri: Uri.parse(galleryMediaUrl(api.baseUrl, asset)),
      headers: api.headers,
      autoPlay: autoPlay,
      quarterTurns: quarterTurns,
      onAspectRatio: onAspectRatio,
      placeholder: storage == null
          ? const _VideoIcon()
          : _LocalPreview(
              key: ValueKey((asset.previewPath, asset.thumbPath, storage)),
              file: () => storage.getDisplayPreview(asset),
              onAspectRatio: onAspectRatio,
            ),
    );
  }
}

class _LocalPreview extends StatefulWidget {
  const _LocalPreview({super.key, required this.file, this.onAspectRatio});

  final Future<File?> Function() file;
  final ValueChanged<double>? onAspectRatio;

  @override
  State<_LocalPreview> createState() => _LocalPreviewState();
}

class _LocalPreviewState extends State<_LocalPreview> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  FileImage? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final File? file;
    try {
      file = await widget.file();
    } catch (_) {
      return;
    }
    if (!mounted || file == null) return;
    final image = FileImage(file);
    setState(() => _image = image);
    if (widget.onAspectRatio == null) return;
    final stream = image.resolve(ImageConfiguration.empty);
    _stream = stream;
    _listener = ImageStreamListener((info, _) {
      _removeListener();
      final ratio = info.image.width / info.image.height;
      info.dispose();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onAspectRatio?.call(ratio);
      });
    }, onError: (_, _) => _removeListener());
    stream.addListener(_listener!);
  }

  void _removeListener() {
    if (_listener case final listener?) _stream?.removeListener(listener);
    _listener = null;
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return image == null
        ? const _VideoIcon()
        : Image(
            image: image,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _VideoIcon(),
          );
  }
}

class _VideoIcon extends StatelessWidget {
  const _VideoIcon();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 64));
}
