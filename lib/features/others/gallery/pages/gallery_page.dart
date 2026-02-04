import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/pages/label_list_page.dart';
import 'package:torrid/features/others/gallery/pages/media_detail_page.dart';
import 'package:torrid/features/others/gallery/pages/medias_gridview_page.dart';
import 'package:torrid/features/others/gallery/pages/setting_page.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/services/gallery_storage_service.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/content_widget.dart';

/// Gallery 模块主页面
/// 媒体文件队列排序规则: 按照 media_assets 表的 captured_at 时间升序排列
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  @override
  void initState() {
    super.initState();
    // 初始化存储目录
    _initStorage();
  }

  Future<void> _initStorage() async {
    final storage = ref.read(galleryStorageProvider);
    await storage.initDirectories();
  }

  @override
  Widget build(BuildContext context) {
    // 设置状态栏样式
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );

    final currentMedia = ref.watch(currentMediaAssetProvider);
    final currentTags = ref.watch(currentMediaTagsProvider);
    final isPreviewAllowed = ref.watch(galleryPreviewAllowedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主体内容
          Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部导航栏
                _buildTopBar(context),

                // 主体内容, 展示当前媒体文件(图片/视频)
                Expanded(
                  child: Center(
                    child: ContentWidget(
                      onDoubleTap: currentMedia != null
                          ? () => _openDetailPage(context)
                          : null,
                    ),
                  ),
                ),

                // 当前媒体的标签显示
                if (currentMedia != null)
                  _buildTagBar(currentTags.valueOrNull ?? []),

                // 底部导航栏
                _buildBottomBar(context, currentMedia),
              ],
            ),
          ),

          // 预览小窗 (启用预览功能时显示)
          if (isPreviewAllowed) const _NextMediaPreviewWidget(),
        ],
      ),
    );
  }

  /// 构建顶部导航栏
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                tooltip: "返回",
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GallerySettingPage()),
                ),
                icon: const Icon(Icons.settings, color: Colors.white),
                tooltip: "设置",
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTagBar(List<dynamic> tags) {
    if (tags.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '暂无标签',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      );
    }

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        itemBuilder: (context, index) {
          final tag = tags[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                tag.name,
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomBar(BuildContext context, dynamic currentMedia) {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        color: Colors.grey[900],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 标签管理
            _BottomBarButton(
              icon: const IconData(0xe63e, fontFamily: "iconfont"),
              label: "标签",
              onPressed: currentMedia != null
                  ? () => _openLabelPage(context, currentMedia.id)
                  : null,
            ),
            // 网格视图 / 捆绑
            _BottomBarButton(
              icon: const IconData(0xe604, fontFamily: "iconfont"),
              label: "网格",
              onPressed: () => _openGridView(context),
            ),
            // 删除当前媒体文件
            _BottomBarButton(
              icon: const IconData(0xe649, fontFamily: "iconfont"),
              label: "删除",
              color: currentMedia?.isDeleted == true ? Colors.red : null,
              onPressed: currentMedia != null
                  ? () => _toggleDelete(currentMedia)
                  : null,
            ),
            // 详情页面
            _BottomBarButton(
              icon: const IconData(0xe611, fontFamily: "iconfont"),
              label: "详情",
              onPressed: currentMedia != null
                  ? () => _openDetailPage(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// 打开标签管理页面
  void _openLabelPage(BuildContext context, String mediaId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabelListPage(mediaId: mediaId)),
    );
  }

  /// 打开网格视图
  void _openGridView(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MediasGridViewPage()),
    );
  }

  /// 切换删除状态
  Future<void> _toggleDelete(dynamic media) async {
    final isCurrentlyDeleted = media.isDeleted;

    if (!isCurrentlyDeleted) {
      // 标记删除 -> 自动跳到下一张（如果有）
      await ref
          .read(mediaAssetListProvider.notifier)
          .markDeleted(media.id, deleted: true);
      
      // 刷新后检查当前索引是否需要调整
      final assets = ref.read(mediaAssetListProvider).valueOrNull ?? [];
      final currentIndex = ref.read(galleryCurrentIndexProvider);
      
      if (assets.isEmpty) {
        // 没有可显示的文件了
        await ref.read(galleryCurrentIndexProvider.notifier).update(0);
      } else if (currentIndex >= assets.length) {
        // 索引超出范围，调整到最后一张
        await ref.read(galleryCurrentIndexProvider.notifier).update(assets.length - 1);
      }
      // 否则保持当前索引（自动显示下一张）
    } else {
      // 取消删除标记
      await ref
          .read(mediaAssetListProvider.notifier)
          .markDeleted(media.id, deleted: false);
    }
  }

  /// 打开详情页面
  void _openDetailPage(BuildContext context) {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaDetailPage(asset: currentMedia)),
    );
  }
}

/// 底部栏按钮
class _BottomBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  const _BottomBarButton({
    required this.icon,
    required this.label,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onPressed == null
        ? Colors.grey[700]
        : (color ?? Colors.white);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: effectiveColor, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: effectiveColor, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

/// 下一个媒体文件预览小窗 (可拖拽)
class _NextMediaPreviewWidget extends ConsumerStatefulWidget {
  const _NextMediaPreviewWidget();

  @override
  ConsumerState<_NextMediaPreviewWidget> createState() =>
      _NextMediaPreviewWidgetState();
}

class _NextMediaPreviewWidgetState
    extends ConsumerState<_NextMediaPreviewWidget> {
  /// 当前位置偏移
  Offset _offset = const Offset(16, 100);

  /// 预览图尺寸
  static const double _previewSize = 80;

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(mediaAssetListProvider);
    final currentIndex = ref.watch(galleryCurrentIndexProvider);
    final storage = ref.watch(galleryStorageProvider);

    return assetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (assets) {
        // 计算下一个媒体的索引
        final nextIndex = currentIndex + 1;

        // 如果是最后一个，不显示预览窗
        if (nextIndex >= assets.length) {
          return const SizedBox.shrink();
        }

        final nextAsset = assets[nextIndex];

        return Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _offset += details.delta;
                // 限制在屏幕范围内
                final screenSize = MediaQuery.of(context).size;
                _offset = Offset(
                  _offset.dx.clamp(0, screenSize.width - _previewSize),
                  _offset.dy.clamp(0, screenSize.height - _previewSize - 100),
                );
              });
            },
            onTap: () {
              // 点击跳转到下一个
              ref.read(galleryCurrentIndexProvider.notifier).update(nextIndex);
            },
            child: Container(
              width: _previewSize,
              height: _previewSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white54, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: FutureBuilder<File?>(
                  future: _getPreviewFile(storage, nextAsset),
                  builder: (context, snapshot) {
                    if (snapshot.data != null) {
                      return Image.file(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        errorBuilder: (_, __, ___) =>
                            _buildPlaceholder(nextAsset),
                      );
                    }
                    return _buildPlaceholder(nextAsset);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 获取预览图文件 (优先预览图 -> 原图)
  Future<File?> _getPreviewFile(
    GalleryStorageService storage,
    MediaAsset asset,
  ) async {
    // 优先使用预览图
    if (asset.previewPath != null) {
      final previewFile = await storage.getPreviewFile(asset.previewPath!);
      if (previewFile != null) return previewFile;
    }

    // 然后原图
    return await storage.getMediaFile(asset.filePath);
  }

  /// 构建占位符
  Widget _buildPlaceholder(MediaAsset asset) {
    return Container(
      color: Colors.grey[800],
      child: Center(
        child: Icon(
          asset.isVideo ? Icons.videocam : Icons.image,
          color: Colors.grey[600],
          size: 32,
        ),
      ),
    );
  }
}
