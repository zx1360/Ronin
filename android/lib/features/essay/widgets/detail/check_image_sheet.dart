import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:torrid/core/services/io/io_service.dart';

/// 双击图片大图展示（支持缩放和滚动）
/// 使用 PhotoView 实现，支持长图滚动查看
void showBigScaledImage(BuildContext context, String path) {
  showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => _FullScreenImageViewer(relativePath: path),
  );
}

/// 全屏图片查看器组件
class _FullScreenImageViewer extends StatefulWidget {
  final String relativePath;

  const _FullScreenImageViewer({required this.relativePath});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  File? _imageFile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final file = await IoService.getImageFile(widget.relativePath);
      if (mounted) {
        setState(() {
          _imageFile = file;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '图片加载失败';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          // 图片查看区域
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_error != null || _imageFile == null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white54,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? '图片不存在',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          else
            PhotoView(
              imageProvider: FileImage(_imageFile!),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              // 最小缩放：适应屏幕
              minScale: PhotoViewComputedScale.contained,
              // 最大缩放：原图的3倍
              maxScale: PhotoViewComputedScale.covered * 3,
              // 初始缩放：适应屏幕宽度，这样长图可以上下滚动
              initialScale: PhotoViewComputedScale.contained,
              // 启用旋转手势
              enableRotation: false,
              // 加载中显示
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              // 错误处理
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),

          // 关闭按钮
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
