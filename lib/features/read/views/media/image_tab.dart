import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';
import 'package:torrid/core/constants/spacing.dart';

/// 可用的图片 API 源
enum ImageApiSource {
  aa1Sjtp2('AA1 随机图片', 'https://api.luochen.sbs/API/sjtp2.php'),
  aa1Whr1('AA1 随机图片 2.0', 'http://api.xunjinlu.fun/api/img2/index.php'),
  x7bbMn('x7bb 美女图片', 'https://x7bb.cn/7/api/?t=mn'),
  x7bbDm('x7bb 动漫图片', 'https://x7bb.cn/7/api/?t=dm');

  final String label;
  final String baseUrl;
  const ImageApiSource(this.label, this.baseUrl);
}

class ImageTab extends ConsumerStatefulWidget {
  const ImageTab({super.key});

  @override
  ConsumerState<ImageTab> createState() => _ImageTabState();
}

class _ImageTabState extends ConsumerState<ImageTab> {
  ImageApiSource _source = ImageApiSource.x7bbMn;
  String? _imageUrl;
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
          const SectionTitle(title: '随机图片', icon: Icons.image),
          const SizedBox(height: AppSpacing.sm),
          _buildApiSelector(context),
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorView(_error!),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildImageResult(context),
        ],
      ),
    );
  }

  Widget _buildApiSelector(BuildContext context) {
    return DropdownButtonFormField<ImageApiSource>(
      initialValue: _source,
      decoration: const InputDecoration(
        labelText: 'API 选择',
        border: OutlineInputBorder(),
      ),
      items: ImageApiSource.values.map((s) {
        return DropdownMenuItem(value: s, child: Text(s.label));
      }).toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _source = v;
          _imageUrl = null;
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
          label: const Text('获取图片'),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: (_imageUrl == null || _loading || _downloading)
              ? null
              : _downloadImage,
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

  Widget _buildImageResult(BuildContext context) {
    if (_imageUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: Text('点击"获取图片"开始浏览。')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => showImagePreview(context, _imageUrl!),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                _imageUrl!,
                key: ValueKey(_imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, _) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text('图片加载失败：$error'),
                    ),
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          _imageUrl!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _imageUrl = null;
      _nonce++;
    });

    try {
      final url = _buildUrl();
      setState(() => _imageUrl = url);
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

  Future<void> _downloadImage() async {
    if (_imageUrl == null) return;
    setState(() => _downloading = true);

    try {
      final client = ref.read(sixtyApiClientProvider);
      final resp = await client.getBinary(_imageUrl!);
      final bytes = resp.data;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) displaySnackBar(context, '下载失败：无数据');
        return;
      }

      final uri = Uri.tryParse(_imageUrl!);
      final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
      final ext = extFromUrl.isNotEmpty ? extFromUrl : 'jpg';

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
}
