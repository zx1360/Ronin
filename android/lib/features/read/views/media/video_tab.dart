import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/features/read/models/random_media_models.dart';
import 'package:torrid/features/read/models/random_media_sources.dart';
import 'package:torrid/features/read/services/media_url_resolver.dart';
import 'package:torrid/features/read/services/media_error_helper.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/media_source_picker.dart';
import 'package:torrid/core/widgets/media/media_video_player.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoTab extends StatefulWidget {
  const VideoTab({super.key, required this.active});

  final bool active;

  @override
  State<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends State<VideoTab>
    with AutomaticKeepAliveClientMixin {
  int _groupIndex = 0;
  int _sourceIndex = 0;

  String? _videoUrl;
  bool _loading = false;
  bool _downloading = false;
  CancelToken? _downloadCancelToken;
  String? _error;

  int _videoRequest = 0;

  MediaApiGroup get _group => kVideoGroups[_groupIndex];
  RandomMediaSource get _source => _group.sources[_sourceIndex];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _downloadCancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _fetchVideo,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '随机视频', icon: Icons.videocam_outlined),
          const SizedBox(height: AppSpacing.sm),
          MediaSourcePicker(
            groups: kVideoGroups,
            groupIndex: _groupIndex,
            sourceIndex: _sourceIndex,
            onChanged: _loading
                ? null
                : (group, source) {
                    setState(() {
                      _groupIndex = group;
                      _sourceIndex = source;
                      _videoUrl = null;
                      _error = null;
                    });
                  },
          ),
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
          child: MediaVideoPlayer(
            key: ValueKey(_videoRequest),
            uri: Uri.parse(_videoUrl!),
            headers: {'User-Agent': kUserAgent, ...?_source.extraHeaders},
            active: widget.active,
            autoPlay: true,
            looping: true,
            allowFullscreen: true,
            openInBrowser: () => _openInBrowser(_videoUrl!),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          _videoUrl!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Future<void> _fetchVideo() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _videoUrl = null;
      _videoRequest++;
    });

    try {
      final url = await MediaUrlResolver.fetchMediaUrl(_source);
      if (!mounted) return;
      setState(() => _videoUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MediaErrorHelper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadVideo() async {
    final url = _videoUrl;
    if (url == null || _downloading) return;
    final token = CancelToken();
    final headers = _source.extraHeaders;
    _downloadCancelToken = token;
    setState(() => _downloading = true);

    try {
      final uri = Uri.tryParse(url);
      final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
      final ext = extFromUrl.isNotEmpty ? extFromUrl : 'mp4';

      final fileName = PublicStorageService.generateUniqueFileName(
        'video',
        ext,
      );
      final file = await PublicStorageService.saveDownload(
        subDir: PublicStorageService.dirApi,
        fileName: fileName,
        download: (target) => MediaUrlResolver.downloadFile(
          url,
          target,
          headers: headers,
          cancelToken: token,
        ),
      );

      if (!mounted) return;
      if (file != null) {
        displaySnackBar(context, '已保存到：${file.location}');
      } else {
        displaySnackBar(context, '保存失败，请检查存储权限');
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      if (!mounted) return;
      displaySnackBar(context, '下载出错：$e');
    } finally {
      _downloadCancelToken = null;
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
