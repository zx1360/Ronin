import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/features/read/models/random_media_models.dart';
import 'package:torrid/features/read/models/random_media_sources.dart';
import 'package:torrid/features/read/services/media_url_resolver.dart';
import 'package:torrid/features/read/services/media_error_helper.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/media_source_picker.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';
import 'package:torrid/core/constants/spacing.dart';

class ImageTab extends ConsumerStatefulWidget {
  const ImageTab({super.key});

  @override
  ConsumerState<ImageTab> createState() => _ImageTabState();
}

class _ImageTabState extends ConsumerState<ImageTab>
    with AutomaticKeepAliveClientMixin {
  int _groupIndex = 0;
  int _sourceIndex = 0;
  Map<String, String> _paramValues = {};

  String? _imageUrl;
  bool _loading = false;
  bool _downloading = false;
  String? _error;

  MediaApiGroup get _group => kImageGroups[_groupIndex];
  RandomMediaSource get _source => _group.sources[_sourceIndex];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initParamValues();
  }

  void _initParamValues() {
    _paramValues = {for (final p in _source.params) p.key: p.defaultValue};
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _fetchImage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionTitle(title: '随机图片', icon: Icons.image_outlined),
          const SizedBox(height: AppSpacing.sm),
          MediaSourcePicker(
            groups: kImageGroups,
            groupIndex: _groupIndex,
            sourceIndex: _sourceIndex,
            onChanged: _loading
                ? null
                : (group, source) {
                    setState(() {
                      _groupIndex = group;
                      _sourceIndex = source;
                      _imageUrl = null;
                      _error = null;
                      _initParamValues();
                    });
                  },
          ),
          ..._source.params.map(
            (p) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _buildParamWidget(p),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildActionButtons(),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorView(_error!),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildImageDisplay(),
        ],
      ),
    );
  }

  // ──────── 选择器 ────────

  Widget _buildParamWidget(ApiParam param) {
    final widgetKey = ValueKey('p_${_groupIndex}_${_sourceIndex}_${param.key}');

    if (param.isTextInput) {
      return TextFormField(
        key: widgetKey,
        decoration: InputDecoration(
          labelText: param.label,
          hintText: param.hint ?? '可选',
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        initialValue: _paramValues[param.key] ?? '',
        onChanged: (v) => _paramValues[param.key] = v,
      );
    }

    return DropdownButtonFormField<String>(
      key: widgetKey,
      initialValue: _paramValues[param.key] ?? param.defaultValue,
      decoration: InputDecoration(
        labelText: param.label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      isExpanded: true,
      items: param.options!
          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _paramValues[param.key] = v);
      },
    );
  }

  // ──────── 操作按钮 ────────

  Widget _buildActionButtons() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        FilledButton.icon(
          onPressed: _loading ? null : _fetchImage,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('获取图片'),
        ),
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

  // ──────── 图片展示 ────────

  Widget _buildImageDisplay() {
    if (_imageUrl == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: Text('点击"获取图片"开始浏览')),
      );
    }

    final headers = <String, String>{
      'User-Agent': kUserAgent,
      ...?_source.extraHeaders,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () =>
                showImagePreview(context, _imageUrl!, headers: headers),
            child: Image.network(
              _imageUrl!,
              key: ValueKey(_imageUrl),
              headers: headers,
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                height: 200,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.broken_image_outlined, size: 48),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '图片加载失败',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                final percent = progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null;
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(value: percent),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          _imageUrl!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ──────── 获取 / 下载 ────────

  Future<void> _fetchImage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _imageUrl = null;
    });

    try {
      final url = await MediaUrlResolver.fetchMediaUrl(_source, _paramValues);
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = MediaErrorHelper.toUserMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadImage() async {
    if (_imageUrl == null) return;
    setState(() => _downloading = true);

    try {
      final bytes = await MediaUrlResolver.downloadBytes(
        _imageUrl!,
        headers: _source.extraHeaders,
      );

      final uri = Uri.tryParse(_imageUrl!);
      final extFromUrl = uri == null ? '' : getFileExtension(uri.path);
      final ext = extFromUrl.isNotEmpty ? extFromUrl : 'jpg';

      final fileName = PublicStorageService.generateUniqueFileName('img', ext);
      final file = await PublicStorageService.saveBytes(
        subDir: PublicStorageService.dirApi,
        fileName: fileName,
        bytes: bytes,
      );

      if (!mounted) return;
      if (file != null) {
        displaySnackBar(context, '已保存到：${file.location}');
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
