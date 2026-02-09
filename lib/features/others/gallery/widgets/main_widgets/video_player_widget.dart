import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:video_player/video_player.dart';

/// 视频播放器组件
/// - 支持网络视频播放
/// - 支持旋转
/// - 使用本地预览图作为占位符
class VideoPlayerWidget extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final int rotationQuarterTurns;
  final GalleryStorageService storage;

  const VideoPlayerWidget({
    super.key,
    required this.asset,
    required this.storage,
    this.rotationQuarterTurns = 0,
  });

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends ConsumerState<VideoPlayerWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  String? _videoError;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // 使用 addPostFrameCallback 确保 context 和 ref 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initVideoPlayer();
    });
  }

  @override
  void didUpdateWidget(covariant VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果 asset 变化，重新初始化视频控制器
    if (oldWidget.asset.id != widget.asset.id) {
      _disposeControllers();
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _videoError = null;
  }

  Future<void> _initVideoPlayer() async {
    if (_isInitializing || !mounted) return;
    _isInitializing = true;

    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final baseUrl = apiClient.baseUrl;
      final headers = apiClient.headers;
      final videoUrl = '$baseUrl/api/gallery/${widget.asset.id}/file';

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: headers,
      );

      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        // 不使用 placeholder，由外部 Stack 控制占位图显示
        errorBuilder: (context, errorMessage) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                '视频加载失败',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = e.toString();
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 错误状态
    if (_videoError != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                '视频加载失败: $_videoError',
                style: TextStyle(color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 加载中状态 - 显示预览图和加载指示器
    if (!_isVideoInitialized) {
      return Container(
        color: Colors.black,
        child: RotatedBox(
          quarterTurns: widget.rotationQuarterTurns,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoPlaceholder(
                asset: widget.asset,
                storage: widget.storage,
              ),
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    // 已初始化 - 显示 Chewie 播放器，应用旋转
    return Container(
      color: Colors.black,
      child: RotatedBox(
        quarterTurns: widget.rotationQuarterTurns,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Chewie(controller: _chewieController!),
          ),
        ),
      ),
    );
  }
}

/// 视频占位图组件
class _VideoPlaceholder extends StatelessWidget {
  final MediaAsset asset;
  final GalleryStorageService storage;

  const _VideoPlaceholder({
    required this.asset,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _getPreviewFile(),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(Icons.videocam, color: Colors.grey, size: 64),
            ),
          );
        }
        return const Center(
          child: Icon(Icons.videocam, color: Colors.grey, size: 64),
        );
      },
    );
  }

  Future<File?> _getPreviewFile() async {
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    if (asset.thumbPath != null) {
      return await storage.getThumbFile(asset.thumbPath!);
    }
    return null;
  }
}
