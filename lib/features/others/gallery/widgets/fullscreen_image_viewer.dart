import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';

/// 全屏图片查看器 (支持缩放和双击放大)
class FullscreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final MediaAsset asset;
  final File? placeholderFile;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.asset,
    this.placeholderFile,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  /// 双击复位或放大
  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // 已放大，复位
      _transformationController.value = Matrix4.identity();
    } else {
      // 放大到2倍
      _transformationController.value = Matrix4.identity()..scale(2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.asset.filePath.split('/').last,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: 'image_${widget.asset.id}',
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) {
                  if (widget.placeholderFile != null) {
                    return Image.file(
                      widget.placeholderFile!,
                      fit: BoxFit.contain,
                    );
                  }
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorWidget: (context, url, error) {
                  if (widget.placeholderFile != null) {
                    return Image.file(
                      widget.placeholderFile!,
                      fit: BoxFit.contain,
                    );
                  }
                  return const Center(
                    child: Icon(Icons.error, color: Colors.red, size: 48),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
