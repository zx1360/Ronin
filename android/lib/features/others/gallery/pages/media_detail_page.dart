import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/features/others/gallery/widgets/fullscreen_image_viewer.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class MediaDetailPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const MediaDetailPage({super.key, required this.asset});

  @override
  ConsumerState<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends ConsumerState<MediaDetailPage> {
  late TextEditingController _messageController;
  bool _isSaving = false;
  bool _isDownloading = false;
  bool _isGroupUpdating = false;
  final _pages = PageController();
  final Map<String, String> _messageDrafts = {};

  List<MediaAsset> _groupMembers = [];

  int _currentGroupIndex = 0;

  MediaAsset get _currentAsset => _groupMembers.isNotEmpty
      ? _groupMembers[_currentGroupIndex]
      : widget.asset;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.asset.message ?? '',
    );
    _loadGroupMembers();
  }

  Future<void> _loadGroupMembers() async {
    try {
      final db = ref.read(galleryDatabaseProvider);
      final leadId = widget.asset.groupId ?? widget.asset.id;
      final lead = await db.getMediaAssetById(leadId) ?? widget.asset;
      final members = await db.getGroupMembers(lead.id);
      if (!mounted) return;
      setState(() {
        _groupMembers = [lead, ...members];
        final index = _groupMembers.indexWhere((a) => a.id == widget.asset.id);
        _currentGroupIndex = index < 0 ? 0 : index;
        _messageController.text =
            _messageDrafts[_currentAsset.id] ?? _currentAsset.message ?? '';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(_currentGroupIndex);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分组加载失败: $e')));
      }
    }
  }

  void _selectGroupIndex(int index) {
    if (index < 0 || index >= _groupMembers.length) return;
    _messageDrafts[_currentAsset.id] = _messageController.text;
    setState(() {
      _currentGroupIndex = index;
      _messageController.text =
          _messageDrafts[_currentAsset.id] ?? _currentAsset.message ?? '';
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(galleryStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getFileName(_currentAsset.filePath),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, size: 20),
            tooltip: '问问AI',
            onPressed: () => askAiAboutMedia(
              context,
              mediaId: _currentAsset.id,
              fileName: _getFileName(_currentAsset.filePath),
            ),
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 20),
            tooltip: '下载',
            onPressed: _isDownloading
                ? null
                : () => _downloadToGallery(storage),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(storage),

            const SizedBox(height: 12),

            _buildMessageSection(),

            const SizedBox(height: 12),

            _buildCompactInfoSection(),

            const SizedBox(height: 12),

            _buildFixedSection('系统信息', [
              _buildInfoRow('ID', _currentAsset.id, fontSize: 11),
              _buildInfoRow(
                '创建',
                _formatDateTime(_currentAsset.createdAt),
                fontSize: 11,
              ),
              _buildInfoRow(
                '更新',
                _formatDateTime(_currentAsset.updatedAt),
                fontSize: 11,
              ),
              _buildInfoRow(
                '同步',
                _currentAsset.syncCount.toString(),
                fontSize: 11,
              ),
              _buildInfoRow('哈希', _currentAsset.hash, fontSize: 11),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(GalleryStorageService storage) {
    final hasGroup = _groupMembers.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            SizedBox(
              height: 260,
              child: hasGroup
                  ? PageView.builder(
                      controller: _pages,
                      itemCount: _groupMembers.length,
                      onPageChanged: _selectGroupIndex,
                      itemBuilder: (context, index) {
                        return _buildPreviewImage(
                          storage,
                          _groupMembers[index],
                          showFullscreen: true,
                        );
                      },
                    )
                  : _buildPreviewImage(
                      storage,
                      _currentAsset,
                      showFullscreen: true,
                    ),
            ),
            if (hasGroup) ...[
              if (_currentGroupIndex > 0)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavButton(Icons.chevron_left, () {
                      _showGroupPage(_currentGroupIndex - 1);
                    }),
                  ),
                ),
              if (_currentGroupIndex < _groupMembers.length - 1)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavButton(Icons.chevron_right, () {
                      _showGroupPage(_currentGroupIndex + 1);
                    }),
                  ),
                ),
            ],
          ],
        ),
        if (hasGroup) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '组内 ${_currentGroupIndex + 1}/${_groupMembers.length} · ${_currentGroupIndex == 0 ? '主文件' : '成员'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: _isGroupUpdating || _isSaving
                    ? null
                    : _removeCurrentFromGroup,
                icon: const Icon(Icons.link_off, size: 16),
                label: Text(_currentGroupIndex == 0 ? '解散分组' : '移出分组'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _showGroupPage(int index) {
    if (_pages.hasClients) {
      _pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _removeCurrentFromGroup() async {
    if (_isGroupUpdating || _groupMembers.length < 2) return;
    final dissolve = _currentGroupIndex == 0;
    final member = _currentAsset;
    final ids = dissolve
        ? _groupMembers.skip(1).map((a) => a.id).toList()
        : [member.id];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dissolve ? '解散分组' : '移出分组'),
        content: Text(
          dissolve
              ? '将所有成员恢复为独立媒体，不删除文件或标注。'
              : '将「${_getFileName(member.filePath)}」恢复为独立媒体，不删除文件或标注。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isGroupUpdating = true);
    try {
      await ref.read(mediaAssetListProvider.notifier).unbundleMedia(ids);
      if (!mounted) return;
      _messageDrafts[member.id] = _messageController.text;
      setState(() {
        _groupMembers.removeWhere((a) => ids.contains(a.id));
        _currentGroupIndex = 0;
        _messageController.text =
            _messageDrafts[_currentAsset.id] ?? _currentAsset.message ?? '';
      });
      if (_pages.hasClients) _pages.jumpToPage(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('解除分组失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGroupUpdating = false);
    }
  }

  Widget _buildCompactInfoSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCompactChip(
                  _currentAsset.mimeType?.split('/').last ?? '未知',
                ),
                const SizedBox(width: 8),
                _buildCompactChip(_formatFileSize(_currentAsset.sizeBytes)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(_currentAsset.capturedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildStatusChip(
                  _currentAsset.isDeleted ? '已删除' : '正常',
                  _currentAsset.isDeleted ? Colors.red : Colors.green,
                ),
                if (_groupMembers.length > 1)
                  _buildStatusChip(
                    _currentGroupIndex == 0
                        ? '主文件(${_groupMembers.length - 1})'
                        : '组成员',
                    Colors.orange,
                  )
                else if (_currentAsset.groupId != null)
                  _buildStatusChip('已捆绑', Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildFixedSection(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewImage(
    GalleryStorageService storage,
    MediaAsset asset, {
    bool showFullscreen = false,
  }) {
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    final imageUrl = galleryMediaUrl(baseUrl, asset);

    return FutureBuilder<File?>(
      future: _getLocalPlaceholder(storage, asset),
      builder: (context, snapshot) {
        final placeholderFile = snapshot.data;

        return GestureDetector(
          onTap: showFullscreen
              ? () => _openFullscreen(imageUrl, asset, placeholderFile, headers)
              : null,
          child: Hero(
            tag: 'image_${asset.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                httpHeaders: headers,
                height: 260,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (context, url) {
                  if (placeholderFile != null) {
                    return Image.file(
                      placeholderFile,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    );
                  }
                  return Container(
                    height: 260,
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorWidget: (context, url, error) {
                  if (placeholderFile != null) {
                    return Image.file(
                      placeholderFile,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    );
                  }
                  return Container(
                    height: 260,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.error, size: 48, color: Colors.red),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<File?> _getLocalPlaceholder(
    GalleryStorageService storage,
    MediaAsset asset,
  ) async {
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    if (asset.thumbPath != null) {
      return await storage.getThumbFile(asset.thumbPath!);
    }
    return null;
  }

  void _openFullscreen(
    String imageUrl,
    MediaAsset asset,
    File? placeholderFile,
    Map<String, String> httpHeaders,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrl: imageUrl,
          asset: asset,
          placeholderFile: placeholderFile,
          httpHeaders: httpHeaders,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    double fontSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: fontSize),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: fontSize, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '留言',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: _isSaving ? null : _saveMessage,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 14),
                    label: const Text('保存', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '添加备注...',
                hintStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMessage() async {
    setState(() => _isSaving = true);

    try {
      final asset = _currentAsset;
      final message = _messageController.text.trim();
      await ref
          .read(mediaAssetListProvider.notifier)
          .setMessage(asset, message);
      if (!mounted) return;
      setState(() {
        final index = _groupMembers.indexWhere((a) => a.id == asset.id);
        if (index >= 0) {
          _groupMembers[index] = _groupMembers[index].copyWith(
            message: message,
          );
        }
        _messageDrafts[asset.id] = message;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _downloadToGallery(GalleryStorageService storage) async {
    final asset = _currentAsset;
    setState(() => _isDownloading = true);

    try {
      final apiClient = ref.read(apiClientManagerProvider);
      final response = await apiClient.getBinary(
        "/API/gallery/${asset.id}/file",
      );

      if (response.data == null || response.data!.isEmpty) {
        throw Exception('下载的文件数据为空');
      }

      final fileName = _getFileName(asset.filePath);
      final Uint8List bytes = response.data!;

      final file = await PublicStorageService.saveBytes(
        subDir: PublicStorageService.dirGallery,
        fileName: fileName,
        bytes: bytes,
      );

      if (file == null) {
        throw Exception('保存到公共目录失败，请检查存储权限');
      }

      AppLogger().info('文件已保存: ${file.path}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到 ${file.path}'),
            action: SnackBarAction(label: '确定', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      AppLogger().error('下载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_pad(dateTime.month)}-${_pad(dateTime.day)} '
        '${_pad(dateTime.hour)}:${_pad(dateTime.minute)}:${_pad(dateTime.second)}';
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
