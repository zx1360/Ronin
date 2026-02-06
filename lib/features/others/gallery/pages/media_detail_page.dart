import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
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
  bool _isSaving = false;
  bool _isDownloading = false;
  
  /// 捆绑的组成员列表 (包括主文件)
  List<MediaAsset> _groupMembers = [];
  
  /// 当前显示的组成员索引
  int _currentGroupIndex = 0;
  
  /// 当前显示的媒体文件
  MediaAsset get _currentAsset => 
      _groupMembers.isNotEmpty ? _groupMembers[_currentGroupIndex] : widget.asset;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.asset.message ?? '');
    _loadGroupMembers();
  }
  
  /// 加载组成员
  Future<void> _loadGroupMembers() async {
    final db = ref.read(galleryDatabaseProvider);
    final members = await db.getGroupMembers(widget.asset.id);
    
    setState(() {
      _groupMembers = [widget.asset, ...members];
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(galleryStorageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getFileName(_currentAsset.filePath), style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download, size: 20),
            tooltip: '下载',
            onPressed: _isDownloading ? null : () => _downloadToGallery(storage),
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

            // 4. 系统信息 (可折叠)
            _buildExpandableSection('系统信息', [
              _buildInfoRow('ID', _currentAsset.id, fontSize: 11),
              _buildInfoRow('创建', _formatDateTime(_currentAsset.createdAt), fontSize: 11),
              _buildInfoRow('更新', _formatDateTime(_currentAsset.updatedAt), fontSize: 11),
              _buildInfoRow('同步', _currentAsset.syncCount.toString(), fontSize: 11),
              _buildInfoRow('哈希', _currentAsset.hash, fontSize: 11),
            ]),
          ],
        ),
      ),
    );
  }

  /// 构建图片展示区域 (带组内导航)
  Widget _buildImageSection(GalleryStorageService storage) {
    final hasGroup = _groupMembers.length > 1;
    
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
                      itemCount: _groupMembers.length,
                      onPageChanged: (index) => setState(() => _currentGroupIndex = index),
                      itemBuilder: (context, index) {
                        return _buildPreviewImage(storage, _groupMembers[index], showFullscreen: true);
                      },
                    )
                  : _buildPreviewImage(storage, widget.asset, showFullscreen: true),
            ),
            // 左右导航按钮 (仅组内)
            if (hasGroup) ...[
              if (_currentGroupIndex > 0)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _buildNavButton(Icons.chevron_left, () {
                      setState(() => _currentGroupIndex--);
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
                      setState(() => _currentGroupIndex++);
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
                  children: List.generate(_groupMembers.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentGroupIndex
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
                      ),
                    );
                  }),
                ),
              ),
              // 移出组按钮 (仅非主文件显示)
              if (_currentGroupIndex > 0)
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
    final currentMember = _groupMembers[_currentGroupIndex];
    if (currentMember.groupId == null) return; // 主文件不能移出
    
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
    
    await ref.read(mediaAssetListProvider.notifier).unbundleMedia([currentMember.id]);
    
    setState(() {
      _groupMembers.removeAt(_currentGroupIndex);
      if (_currentGroupIndex >= _groupMembers.length) {
        _currentGroupIndex = _groupMembers.length - 1;
      }
    });
  }

  /// 构建紧凑型信息区
  Widget _buildCompactInfoSection() {
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
                _buildCompactChip(_currentAsset.mimeType?.split('/').last ?? '未知'),
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
            // 第二行: 状态标签
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
                    _currentGroupIndex == 0 ? '主文件(${_groupMembers.length - 1})' : '组成员',
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
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
  
  /// 构建可折叠信息区
  Widget _buildExpandableSection(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        dense: true,
        children: children,
      ),
    );
  }

  /// 构建预览图 (点击可全屏)
  Widget _buildPreviewImage(GalleryStorageService storage, MediaAsset asset, {bool showFullscreen = false}) {
    // 获取网络图片 URL
    final baseUrl = ref.read(apiClientManagerProvider).baseUrl;
    final imageUrl = '$baseUrl/api/gallery/${asset.id}/file';
    
    return FutureBuilder<File?>(
      future: _getLocalPlaceholder(storage, asset),
      builder: (context, snapshot) {
        final placeholderFile = snapshot.data;
        
        return GestureDetector(
          onTap: showFullscreen ? () => _openFullscreen(imageUrl, asset, placeholderFile) : null,
          child: Hero(
            tag: 'image_${asset.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
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
  void _openFullscreen(String imageUrl, MediaAsset asset, File? placeholderFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrl: imageUrl,
          asset: asset,
          placeholderFile: placeholderFile,
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
                    onPressed: _isSaving ? null : _saveMessage,
                    icon: _isSaving
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
    setState(() => _isSaving = true);

    try {
      final db = ref.read(galleryDatabaseProvider);
      final updatedAsset = widget.asset.copyWith(
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      await db.updateMediaAsset(updatedAsset);
      ref.invalidate(mediaAssetListProvider);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 下载到相册
  Future<void> _downloadToGallery(GalleryStorageService storage) async {
    setState(() => _isDownloading = true);

    try {
      // 请求存储权限
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // 尝试请求照片权限 (Android 13+)
        final photosStatus = await Permission.photos.request();
        if (!photosStatus.isGranted) {
          throw Exception('需要存储权限才能下载文件');
        }
      }

      // 获取源文件
      final sourceFile = await storage.getMediaFile(widget.asset.filePath);
      if (sourceFile == null) {
        throw Exception('源文件不存在');
      }

      // 构建目标路径
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('无法访问外部存储');
      }

      // 使用公共 Pictures 目录
      final picturesDir = Directory('/storage/emulated/0/Pictures/Torrid/gallery');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      final fileName = _getFileName(widget.asset.filePath);
      final targetPath = p.join(picturesDir.path, fileName);
      final targetFile = File(targetPath);

      // 检查是否已存在
      if (await targetFile.exists()) {
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('文件已存在'),
            content: Text('文件 "$fileName" 已存在，是否覆盖？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('覆盖'),
              ),
            ],
          ),
        );

        if (overwrite != true) {
          return;
        }
      }

      // 复制文件
      await sourceFile.copy(targetPath);

      AppLogger().info('文件已下载到: $targetPath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已下载到: ${picturesDir.path}'),
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
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
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