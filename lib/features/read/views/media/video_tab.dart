import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:url_launcher/url_launcher.dart';

/// 可用的视频 API 源
enum VideoApiSource {
  x7bbMnVideo('x7bb 美女视频', 'https://x7bb.cn/7/api/?t=mn'),
  x7bbDmVideo('x7bb 动漫视频', 'https://x7bb.cn/7/api/?t=dm');

  final String label;
  final String baseUrl;
  const VideoApiSource(this.label, this.baseUrl);
}

class VideoTab extends ConsumerStatefulWidget {
  const VideoTab({super.key});

  @override
  ConsumerState<VideoTab> createState() => _VideoTabState();
}

class _VideoTabState extends ConsumerState<VideoTab> {
  VideoApiSource _source = VideoApiSource.x7bbMnVideo;
  String? _videoUrl;
  bool _loading = false;
  bool _downloading = false;
  String? _error;
  int _nonce = 0;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '随机视频', icon: Icons.videocam),
          const SizedBox(height: AppSpacing.sm),
          _buildApiSelector(context),
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorView(_error!),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildVideoResult(context),
        ],
      ),
    );
  }

  Widget _buildApiSelector(BuildContext context) {
    return DropdownButtonFormField<VideoApiSource>(
      initialValue: _source,
      decoration: const InputDecoration(
        labelText: 'API 选择',
        border: OutlineInputBorder(),
      ),
      items: VideoApiSource.values.map((s) {
        return DropdownMenuItem(value: s, child: Text(s.label));
      }).toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _source = v;
          _videoUrl = null;
          _error = null;
        });
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        FilledButton.icon(
          onPressed: _loading ? null : _refresh,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('获取视频'),
        ),
        const SizedBox(width: AppSpacing.sm),
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
      ],
    );
  }

  Widget _buildVideoResult(BuildContext context) {
    if (_videoUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: Text('点击"获取视频"开始浏览。')),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_outline, size: 28),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('视频链接已获取，点击下方按钮打开或保存。'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SelectableText(
              _videoUrl!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => _openUrl(context, _videoUrl!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('在浏览器中打开'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _videoUrl = null;
      _nonce++;
    });

    try {
      final url = _buildUrl();
      setState(() => _videoUrl = url);
    } catch (e) {
      setState(() => _error = '获取失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _buildUrl() {
    final uri = Uri.parse(_source.baseUrl);
    final qp = Map<String, dynamic>.from(uri.queryParameters);
    qp['_ts'] = DateTime.now().millisecondsSinceEpoch.toString();
    qp['_n'] = _nonce.toString();
    return uri.replace(queryParameters: qp).toString();
  }

  Future<void> _downloadVideo() async {
    if (_videoUrl == null) return;
    setState(() => _downloading = true);

    try {
      final client = ref.read(sixtyApiClientProvider);
      final resp = await client.getBinary(_videoUrl!);
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) displaySnackBar(context, '下载失败：无数据');
        return;
      }

      final uri = Uri.tryParse(_videoUrl!);
      final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
      final ext = extFromUrl.isNotEmpty ? extFromUrl : 'mp4';

      final fileName = PublicStorageService.generateUniqueFileName(
        _source.name,
        ext,
      );
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      displaySnackBar(context, 'URL 无效');
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      displaySnackBar(context, '无法打开链接');
    }
  }
}
