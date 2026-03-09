import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/features/read/models/random_media_api.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class VideoTab extends ConsumerStatefulWidget {
  const VideoTab({super.key});

  @override
  ConsumerState<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends ConsumerState<VideoTab>
    with AutomaticKeepAliveClientMixin {
  int _sourceIndex = 0;
  String? _videoUrl;
  bool _loading = false;
  bool _downloading = false;
  String? _error;

  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _playerReady = false;
  String? _playerError;

  RandomMediaSource get _source => kVideoApiSources[_sourceIndex];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    _playerReady = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _fetchVideo,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '随机视频', icon: Icons.videocam_outlined),
          const SizedBox(height: AppSpacing.sm),
          _buildApiSelector(),
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorView(_error!),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildVideoDisplay(),
        ],
      ),
    );
  }

  Widget _buildApiSelector() {
    return DropdownButtonFormField<int>(
      initialValue: _sourceIndex,
      decoration: const InputDecoration(
        labelText: 'API 源',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      isExpanded: true,
      items: List.generate(kVideoApiSources.length, (i) {
        return DropdownMenuItem(
          value: i,
          child: Text(kVideoApiSources[i].label),
        );
      }),
      onChanged: (v) {
        if (v == null) return;
        _disposePlayer();
        setState(() {
          _sourceIndex = v;
          _videoUrl = null;
          _error = null;
          _playerError = null;
        });
      },
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: _loading ? null : _fetchVideo,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('获取视频'),
        ),
        OutlinedButton.icon(
          onPressed: (_videoUrl == null || _loading || _downloading)
              ? null
              : _downloadVideo,
          icon: _downloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: const Text('保存到本地'),
        ),
        if (_videoUrl != null)
          OutlinedButton.icon(
            onPressed: () => _openInBrowser(_videoUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const Text('浏览器打开'),
          ),
      ],
    );
  }

  Widget _buildVideoDisplay() {
    if (_videoUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: Text('点击"获取视频"开始浏览')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildPlayer(),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          _videoUrl!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildPlayer() {
    if (_playerError != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '视频加载失败',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: () => _openInBrowser(_videoUrl!),
                child: const Text('在浏览器中打开'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_playerReady || _chewieController == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }

    final ar = _videoController!.value.aspectRatio;
    return AspectRatio(
      aspectRatio: ar > 0 ? ar : 16 / 9,
      child: Chewie(controller: _chewieController!),
    );
  }

  Future<void> _fetchVideo() async {
    setState(() {
      _loading = true;
      _error = null;
      _videoUrl = null;
      _playerError = null;
    });
    _disposePlayer();

    try {
      final url = await MediaUrlResolver.fetchMediaUrl(_source);
      if (!mounted) return;
      setState(() => _videoUrl = url);
      await _initPlayer(url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '获取失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _initPlayer(String url) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = controller;
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      _chewieController = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        looping: true,
        showOptions: false,
      );
      setState(() => _playerReady = true);
    } catch (e) {
      if (mounted) setState(() => _playerError = e.toString());
    }
  }

  Future<void> _downloadVideo() async {
    if (_videoUrl == null) return;
    setState(() => _downloading = true);

    try {
      final bytes = await MediaUrlResolver.downloadBytes(_videoUrl!);

      final uri = Uri.tryParse(_videoUrl!);
      final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
      final ext = extFromUrl.isNotEmpty ? extFromUrl : 'mp4';

      final fileName =
          PublicStorageService.generateUniqueFileName('video', ext);
      final file = await PublicStorageService.saveBytes(
        subDir: PublicStorageService.dirApi,
        fileName: fileName,
        bytes: bytes,
      );

      if (!mounted) return;
      if (file != null) {
        displaySnackBar(context, '已保存到：${file.path}');
      } else {
        displaySnackBar(context, '保存失败，请检查存储权限');
      }
    } catch (e) {
      if (!mounted) return;
      displaySnackBar(context, '下载出错：$e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) displaySnackBar(context, 'URL 无效');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      displaySnackBar(context, '无法打开链接');
    }
  }
}
