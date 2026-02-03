import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';

/// 媒体文件详情页
/// - 展示该媒体文件的各详细信息
/// - 提供下载按钮（下载到外部公有空间 /Pictures/Torrid/gallery/）
/// - 提供留言功能（写入 message 字段）
/// - 组件排序: 图片-留言-基本信息-状态信息-系统信息
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

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.asset.message ?? '');
    _loadGroupMembers();
  }
  
  /// 加载组成员
  Future<void> _loadGroupMembers() async {
    final db = ref.read(galleryDatabaseProvider);
    
    // 如果当前文件有 groupId，说明它是被捆绑的从属文件
    // 如果当前文件没有 groupId 但被其他文件捆绑，则它是主文件
    final members = await db.getGroupMembers(widget.asset.id);
    
    setState(() {
      // 主文件 + 组成员
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
        title: const Text('文件详情'),
        actions: [
          // 下载按钮
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: '下载到相册',
            onPressed: _isDownloading ? null : () => _downloadToGallery(storage),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 大图展示 (可点击全屏)
            _buildImageSection(storage),

            const SizedBox(height: 24),

            // 2. 留言区域
            _buildMessageSection(),

            const SizedBox(height: 16),

            // 3. 基本信息
            _buildInfoSection('基本信息', [
              _buildInfoRow('文件名', _getFileName(widget.asset.filePath)),
              _buildInfoRow('文件类型', widget.asset.mimeType ?? '未知'),
              _buildInfoRow('文件大小', _formatFileSize(widget.asset.sizeBytes)),
              _buildInfoRow('拍摄时间', _formatDateTime(widget.asset.capturedAt)),
            ]),

            const SizedBox(height: 16),

            // 4. 状态信息
            _buildInfoSection('状态信息', [
              _buildInfoRow(
                '删除状态',
                widget.asset.isDeleted ? '已标记删除' : '正常',
                valueColor: widget.asset.isDeleted ? Colors.red : Colors.green,
              ),
              _buildInfoRow(
                '捆绑状态',
                widget.asset.groupId != null 
                    ? '已捆绑' 
                    : (_groupMembers.length > 1 ? '主文件 (${_groupMembers.length - 1}个从属)' : '独立文件'),
                valueColor: widget.asset.groupId != null || _groupMembers.length > 1 
                    ? Colors.amber 
                    : null,
              ),
              if (widget.asset.groupId != null)
                _buildInfoRow('主文件 ID', widget.asset.groupId!),
            ]),

            const SizedBox(height: 16),

            // 5. 系统信息
            _buildInfoSection('系统信息', [
              _buildInfoRow('ID', widget.asset.id),
              _buildInfoRow('创建时间', _formatDateTime(widget.asset.createdAt)),
              _buildInfoRow('更新时间', _formatDateTime(widget.asset.updatedAt)),
              _buildInfoRow('同步次数', widget.asset.syncCount.toString()),
              _buildInfoRow('文件哈希', widget.asset.hash),
            ]),

            const SizedBox(height: 16),

            // 路径信息
            _buildInfoSection('路径信息', [
              _buildInfoRow('原文件', widget.asset.filePath),
              if (widget.asset.thumbPath != null)
                _buildInfoRow('缩略图', widget.asset.thumbPath!),
              if (widget.asset.previewPath != null)
                _buildInfoRow('预览图', widget.asset.previewPath!),
            ]),
          ],
        ),
      ),
    );
  }

  /// 构建图片展示区域
  Widget _buildImageSection(GalleryStorageService storage) {
    // 如果有组成员，显示可滑动的图片列表
    if (_groupMembers.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '组合文件 (${_currentGroupIndex + 1}/${_groupMembers.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 300,
            child: PageView.builder(
              itemCount: _groupMembers.length,
              onPageChanged: (index) {
                setState(() => _currentGroupIndex = index);
              },
              itemBuilder: (context, index) {
                final member = _groupMembers[index];
                return _buildPreviewImage(storage, member, showFullscreen: true);
              },
            ),
          ),
          const SizedBox(height: 8),
          // 指示器
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_groupMembers.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentGroupIndex
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ],
      );
    }
    
    // 单个文件显示
    return _buildPreviewImage(storage, widget.asset, showFullscreen: true);
  }

  /// 构建预览图 (点击可全屏)
  Widget _buildPreviewImage(GalleryStorageService storage, MediaAsset asset, {bool showFullscreen = false}) {
    return FutureBuilder<File?>(
      future: _getDisplayFile(storage, asset),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final file = snapshot.data;
        if (file == null) {
          return Container(
            height: 300,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
          );
        }

        return GestureDetector(
          onTap: showFullscreen ? () => _openFullscreen(file, asset) : null,
          child: Hero(
            tag: 'image_${asset.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                file,
                height: 300,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.error, size: 64, color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 获取显示用的文件 (原图 -> 预览图 -> 缩略图)
  Future<File?> _getDisplayFile(GalleryStorageService storage, MediaAsset asset) async {
    // 优先使用原图
    final mediaFile = await storage.getMediaFile(asset.filePath);
    if (mediaFile != null) return mediaFile;
    
    // 然后预览图
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }
    
    // 最后缩略图
    if (asset.thumbPath != null) {
      return await storage.getThumbFile(asset.thumbPath!);
    }
    
    return null;
  }
  
  /// 打开全屏查看器
  void _openFullscreen(File file, MediaAsset asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(
          file: file,
          asset: asset,
        ),
      ),
    );
  }

  /// 构建信息区域
  Widget _buildInfoSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建留言区域
  Widget _buildMessageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '留言',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _saveMessage,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: const Text('保存'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '添加备注或留言...',
                border: OutlineInputBorder(),
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

/// 全屏图片查看器 (支持缩放)
class _FullscreenImageViewer extends StatefulWidget {
  final File file;
  final MediaAsset asset;

  const _FullscreenImageViewer({
    required this.file,
    required this.asset,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  /// 双击复位或放大
  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // 已放大，复位
      _transformationController.value = Matrix4.identity();
    } else {
      // 放大到2倍
      _transformationController.value = Matrix4.identity()..scale(2.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.asset.filePath.split('/').last,
          style: const TextStyle(fontSize: 14),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: 'image_${widget.asset.id}',
              child: Image.file(
                widget.file,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}