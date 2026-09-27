import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/features/others/gallery/widgets/fullscreen_image_viewer.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 媒体文件详情页 - 更紧凑的UI设计
class MediaDetailPage extends ConsumerStatefulWidget {
  final MediaAsset asset;

  const MediaDetailPage({
    super.key,
    required this.asset,
  });

  @override
  ConsumerState<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends ConsumerState<MediaDetailPage> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.asset.message ?? '');
    // 组成员 / 备注 / 下载等状态由 Provider 持有
    ref.read(mediaDetailProvider.notifier).load(widget.asset);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(galleryStorageProvider);
    final detail = ref.watch(mediaDetailProvider);
    final asset = detail.current ?? widget.asset;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getFileName(asset.filePath), style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, size: 20),
            tooltip: '问问AI',
            onPressed: () => askAiAboutMedia(
              context,
              mediaId: asset.id,
              fileName: _getFileName(asset.filePath),
            ),
          ),
          IconButton(
            icon: detail.downloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download, size: 20),
            tooltip: '下载',
            onPressed: detail.downloading ? null : _downloadToGallery,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 图片展示区 + 组内导航
            _buildImageSection(storage),

            const SizedBox(height: 12),

            // 2. 留言区域 (紧凑型)
            _buildMessageSection(),

            const SizedBox(height: 12),

            // 3. 基本信息 + 状态信息 (合并为更紧凑)
            _buildCompactInfoSection(),

            const SizedBox(height: 12),

            // 4. 系统信息 (常驻展开)
            _buildFixedSection('系统信息', [
              _buildInfoRow('ID', asset.id, fontSize: 11),
              _buildInfoRow('创建', _formatDateTime(asset.createdAt), fontSize: 11),
              _buildInfoRow('更新', _formatDateTime(asset.updatedAt), fontSize: 11),
              _buildInfoRow('同步', asset.syncCount.toString(), fontSize: 11),
              _buildInfoRow('哈希', asset.hash, fontSize: 11),
            ]),
          ],
        ),
      ),
    );
  }

  /// 切换当前查看的组成员，并同步备注输入框（备注是逐文件的）
  void _selectGroupIndex(int index) {
    final members = ref.read(mediaDetailProvider).groupMembers;
    if (index < 0 || index >= members.length) return;
    ref.read(mediaDetailProvider.notifier).selectIndex(index);
    _messageController.text = members[index].message ?? '';
  }

  /// 构建图片展示区域 (带组内导航)
  Widget _buildImageSection(GalleryStorageService storage) {
    final detail = ref.watch(mediaDetailProvider);
    final asset = detail.current ?? widget.asset;
    final hasGroup = detail.hasGroup;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图片展示
        Stack(
          children: [
            SizedBox(
              height: 260,
              child: hasGroup
                  ? PageView.builder(
                      itemCount: detail.groupMembers.length,
                      onPageChanged: _selectGroupIndex,
                      itemBuilder: (context, index) {
                        return _buildPreviewImage(storage, detail.groupMembers[index], showFullscreen: true);
                      },
                    )
                  : _buildPreviewImage(storage, asset, showFullscreen: true),
            ),
            // 左右导航按钮 (仅组内)
            if (hasGroup) ...[
              if (detail.groupIndex > 0)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavButton(Icons.chevron_left, () {
                      _selectGroupIndex(detail.groupIndex - 1);
                    }),
                  ),
                ),
              if (detail.groupIndex < detail.groupMembers.length - 1)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavButton(Icons.chevron_right, () {
                      _selectGroupIndex(detail.groupIndex + 1);
                    }),
                  ),
                ),
            ],
          ],
        ),
        // 组内信息条
        if (hasGroup) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              // 指示器
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(detail.groupMembers.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == detail.groupIndex
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
                      ),
                    );
                  }),
                ),
              ),
              // 移出组按钮 (仅非主文件显示)
              if (detail.groupIndex > 0)
                TextButton.icon(
                  onPressed: _removeCurrentFromGroup,
                  icon: const Icon(Icons.link_off, size: 16),
                  label: const Text('移出组', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
  
  /// 构建导航按钮
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
  
  /// 移除当前文件从组中
  Future<void> _removeCurrentFromGroup() async {
    final currentMember = ref.read(mediaDetailProvider).current;
    if (currentMember == null || currentMember.groupId == null) return; // 主文件不能移出
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移出组'),
        content: Text('确定要将 "${_getFileName(currentMember.filePath)}" 从组中移出吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    
    if (confirm != true) return;

    try {
      await ref.read(mediaDetailProvider.notifier).removeCurrentFromGroup();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('移出组失败: $e')));
      }
    }
  }

  /// 构建紧凑型信息区
  Widget _buildCompactInfoSection() {
    final detail = ref.watch(mediaDetailProvider);
    final asset = detail.current ?? widget.asset;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行: 文件类型 | 大小 | 拍摄时间
            Row(
              children: [
                _buildCompactChip(asset.mimeType?.split('/').last ?? '未知'),
                const SizedBox(width: 8),
                _buildCompactChip(_formatFileSize(asset.sizeBytes)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDateTime(asset.capturedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 第二行: 状态标签
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildStatusChip(
                  asset.isDeleted ? '已删除' : '正常',
                  asset.isDeleted ? Colors.red : Colors.green,
                ),
                if (detail.hasGroup)
                  _buildStatusChip(
                    detail.groupIndex == 0 ? '主文件(${detail.groupMembers.length - 1})' : '组成员',
                    Colors.orange,
                  )
                else if (asset.groupId != null)
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
  
  /// 构建常驻展开信息区
  Widget _buildFixedSection(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建预览图 (点击可全屏)
  Widget _buildPreviewImage(GalleryStorageService storage, MediaAsset asset, {bool showFullscreen = false}) {
    // 获取网络图片 URL
    final apiClient = ref.read(apiClientManagerProvider);
    final baseUrl = apiClient.baseUrl;
    final headers = apiClient.headers;
    final imageUrl = '$baseUrl${ApiPath.galleryIdTypePath(asset.id, 'file')}';
    
    return FutureBuilder<File?>(
      future: _getLocalPlaceholder(storage, asset),
      builder: (context, snapshot) {
        final placeholderFile = snapshot.data;
        
        return GestureDetector(
          onTap: showFullscreen ? () => _openFullscreen(imageUrl, asset, placeholderFile, headers) : null,
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
                  // 加载失败时显示本地预览图
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
  
  /// 获取本地占位图 (优先预览图, 其次缩略图)
  Future<File?> _getLocalPlaceholder(GalleryStorageService storage, MediaAsset asset) async {
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    if (asset.thumbPath != null) {
      return await storage.getThumbFile(asset.thumbPath!);
    }
    return null;
  }
  
  /// 打开全屏查看器
  void _openFullscreen(String imageUrl, MediaAsset asset, File? placeholderFile, Map<String, String> httpHeaders) {
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

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor, double fontSize = 12}) {
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
              style: TextStyle(
                fontSize: fontSize,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建留言区域 (紧凑型)
  Widget _buildMessageSection() {
    final saving = ref.watch(mediaDetailProvider).saving;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('留言', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: saving ? null : _saveMessage,
                    icon: saving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save, size: 14),
                    label: const Text('保存', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
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
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存留言
  Future<void> _saveMessage() async {
    try {
      await ref
          .read(mediaDetailProvider.notifier)
          .saveMessage(_messageController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  /// 下载到公共存储目录
  Future<void> _downloadToGallery() async {
    try {
      final path = await ref.read(mediaDetailProvider.notifier).downloadToPublic();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到 $path'),
            action: SnackBarAction(
              label: '确定',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger().error('下载失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  /// 获取文件名
  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  /// 格式化文件大小
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

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${_pad(dateTime.month)}-${_pad(dateTime.day)} '
        '${_pad(dateTime.hour)}:${_pad(dateTime.minute)}:${_pad(dateTime.second)}';
  }

  String _pad(int value) => value.toString().padLeft(2, '0');
}
