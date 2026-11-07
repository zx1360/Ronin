import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/models/media_orientation.dart';
import 'package:torrid/features/others/gallery/models/tag.dart';
import 'package:torrid/features/others/gallery/pages/image_editor_page.dart';
import 'package:torrid/features/others/gallery/pages/label_list_page.dart';
import 'package:torrid/features/others/gallery/pages/media_detail_page.dart';
import 'package:torrid/features/others/gallery/pages/medias_browser_page.dart';
import 'package:torrid/features/others/gallery/pages/setting_page.dart';
import 'package:torrid/features/others/gallery/pages/video_trimmer_page.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/content_widget.dart';
import 'package:torrid/features/others/gallery/widgets/preview_window_widget.dart';
import 'package:torrid/features/others/gallery/widgets/tag_drag_overlay.dart';

/// 解析编辑参数 JSON，生成人类可读的编辑提示文本。
/// 返回 null 表示没有有效的编辑信息。
String? parseEditInfo(MediaAsset? media) {
  if (media == null || media.editParams == null) return null;
  try {
    final json = jsonDecode(media.editParams as String) as Map<String, dynamic>;
    final type = json['type'] as String?;
    if (type == 'image') {
      final rot = json['rotation'] as int? ?? 0;
      final hasCrop = json['crop_left'] != null;
      final parts = <String>[];
      if (rot != 0) parts.add('旋转$rot°');
      if (hasCrop) parts.add('裁剪中');
      return parts.isEmpty ? null : '编辑: ${parts.join(' · ')}';
    } else if (type == 'video') {
      final start = (json['trim_start_sec'] as num?)?.toDouble();
      final end = (json['trim_end_sec'] as num?)?.toDouble();
      final parts = <String>[];
      if (start != null && start > 0) parts.add(_formatSeconds(start));
      if (end != null && end > 0) parts.add(_formatSeconds(end));
      return parts.isEmpty ? null : '剪辑: ${parts.join(' → ')}';
    }
  } catch (_) {}
  return null;
}

String _formatSeconds(double sec) {
  final m = (sec / 60).floor();
  final s = (sec % 60).floor();
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Gallery 模块主页面
/// 媒体文件队列排序规则: 按照 media_assets 表的 captured_at 时间升序排列
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  /// 顶部/底部工具栏是否可见
  bool _barsVisible = true;

  /// 旋转角度 (0, 1, 2, 3 表示 0°, 90°, 180°, 270°)
  int _quarterTurns = 0;
  String? _ratioMediaId;
  double? _aspectRatio;
  String? _manualMediaId;

  /// 拖拽打标签浮层控制器（由"标签"按钮手势驱动）
  final GlobalKey<TagDragOverlayState> _tagDragKey = GlobalKey();

  /// 数值配置
  Color get _barBackgroundColor => Color.fromRGBO(0, 0, 0, 0.25);
  double get _toolbarHeight =>
      44 * MediaQuery.textScalerOf(context).scale(14) / 14;

  @override
  void initState() {
    super.initState();
    ref.read(galleryWriteBufferProvider).retry();
    _initStorage();
  }

  Future<void> _initStorage() async {
    final storage = ref.read(galleryStorageProvider);
    await storage.initDirectories();
  }

  void _toggleBarsVisibility() {
    setState(() => _barsVisible = !_barsVisible);
  }

  void _toggleRotation() {
    _manualMediaId = ref.read(currentMediaAssetProvider)?.id;
    setState(() => _quarterTurns = _quarterTurns == 0 ? 1 : 0);
  }

  void _onAspectRatio(String id, double ratio) {
    if (!mounted || ref.read(currentMediaAssetProvider)?.id != id) return;
    _ratioMediaId = id;
    _aspectRatio = ratio;
    if (!ref.read(galleryAutoOrientationProvider) || _manualMediaId == id) {
      return;
    }
    final turns = mediaOrientationTurns(ratio, _quarterTurns);
    if (turns != _quarterTurns) setState(() => _quarterTurns = turns);
  }

  Future<void> _toggleAutoOrientation() async {
    await ref
        .read(galleryAutoOrientationProvider.notifier)
        .update(!ref.read(galleryAutoOrientationProvider));
    if (!mounted) return;
    _manualMediaId = null;
    if (_ratioMediaId != null && _aspectRatio != null) {
      _onAspectRatio(_ratioMediaId!, _aspectRatio!);
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
    );

    final currentMedia = ref.watch(currentMediaAssetProvider);
    final currentTags = ref.watch(currentMediaTagsProvider);
    final inGroup = ref.watch(galleryActiveGroupProvider) != null;
    ref.listen(currentMediaAssetProvider, (previous, next) {
      if (previous?.id != next?.id) _manualMediaId = null;
    });

    // 本地保存异常的提示。
    ref.listen(galleryWriteStatusProvider, (prev, next) {
      if (next == null || next == prev) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
      );
      ref.read(galleryWriteStatusProvider.notifier).clear();
    });

    final mediaQuery = MediaQuery.of(context);
    final topBarHeight = mediaQuery.padding.top + _toolbarHeight;
    final bottomBarHeight = mediaQuery.padding.bottom + 56 + 40;

    return PopScope(
      canPop: !inGroup,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inGroup) {
          ref.read(currentMediaAssetProvider.notifier).closeGroup();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: ContentWidget(
                rotationQuarterTurns: _quarterTurns,
                onAspectRatio: _onAspectRatio,
                onToggleBars: _toggleBarsVisibility,
                onPrevious: _goToPrevious,
                onNext: _goToNext,
                onRotate: _toggleRotation,
                topExcludeHeight: _barsVisible ? topBarHeight : 0,
                bottomExcludeHeight: _barsVisible ? bottomBarHeight : 0,
              ),
            ),

            // 顶部导航栏 (可切换显示/隐藏)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 0),
              curve: Curves.easeInOut,
              top: _barsVisible ? 0 : -topBarHeight,
              left: 0,
              right: 0,
              child: _buildTopBar(context),
            ),

            // 底部区域 (标签栏 + 导航栏)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 0),
              curve: Curves.easeInOut,
              bottom: _barsVisible ? 0 : -bottomBarHeight,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 当前媒体的标签显示
                  if (currentMedia != null)
                    _buildTagBar(currentTags.valueOrNull ?? []),
                  // 底部导航栏
                  _buildBottomBar(context, currentMedia),
                ],
              ),
            ),

            // 预览小窗 - 仅在启用且存在下一个文件时显示
            if (ref.watch(galleryPreviewWindowEnabledProvider))
              PreviewWindowWidget(
                onTap: _goToNext,
                rotationQuarterTurns: _quarterTurns,
              ),

            // 拖拽打标签浮层（非拖动时为空组件，不拦截任何交互）
            Positioned.fill(
              child: TagDragOverlay(
                key: _tagDragKey,
                bottomInset: _barsVisible ? bottomBarHeight : 8,
                // 浮层跟随媒体旋转方向，横向看图时打标签不必再转手机
                quarterTurns: _quarterTurns,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final currentMedia = ref.watch(currentMediaAssetProvider);
    final fileName =
        currentMedia?.filePath.split('/').last.split('\\').last ?? '';
    final editInfo = parseEditInfo(currentMedia);
    final inGroup = ref.watch(galleryActiveGroupProvider) != null;
    final groupAssets =
        ref.watch(galleryBrowsingAssetsProvider).valueOrNull ?? [];
    final groupIndex = ref.watch(galleryBrowsingIndexProvider);

    return Container(
      color: _barBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _toolbarHeight,
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (inGroup) {
                    ref.read(currentMediaAssetProvider.notifier).closeGroup();
                  } else {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 22,
                ),
                tooltip: inGroup ? '返回主列表' : '返回',
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (inGroup)
                      Text(
                        groupAssets.isEmpty
                            ? '组内浏览'
                            : '组内 ${groupIndex + 1}/${groupAssets.length} · ${currentMedia?.groupId == null ? '主文件' : '成员'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                        ),
                      ),
                    if (!inGroup && editInfo != null)
                      Text(
                        editInfo,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: currentMedia != null && !currentMedia.isDeleted
                    ? () => _openEditor(context, currentMedia)
                    : null,
                icon: Icon(
                  Icons.edit,
                  color: currentMedia != null && !currentMedia.isDeleted
                      ? Colors.white
                      : Colors.grey[700]!,
                  size: 22,
                ),
                tooltip: "编辑",
              ),
              IconButton(
                onPressed: _toggleAutoOrientation,
                icon: Icon(
                  Icons.screen_rotation,
                  size: 22,
                  color: ref.watch(galleryAutoOrientationProvider)
                      ? Colors.lightBlueAccent
                      : Colors.white,
                ),
                tooltip: ref.watch(galleryAutoOrientationProvider)
                    ? '自动方向：开启'
                    : '自动方向：关闭',
              ),
              IconButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GallerySettingPage()),
                ),
                icon: const Icon(Icons.settings, color: Colors.white, size: 22),
                tooltip: "设置",
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签栏
  Widget _buildTagBar(List<Tag> tags) {
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
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
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
  Widget _buildBottomBar(BuildContext context, MediaAsset? currentMedia) {
    final inGroup = ref.watch(galleryActiveGroupProvider) != null;
    final groupSize =
        ref.watch(mediaGroupSizesProvider).valueOrNull?[currentMedia?.groupId ??
            currentMedia?.id] ??
        0;
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        color: _barBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 标签管理：点击打开标签管理页；向上拖动激活"拖拽打标签"浮层；长按打开常驻浮层
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: currentMedia != null
                  ? (d) => _tagDragKey.currentState?.startDrag(d.globalPosition)
                  : null,
              onPanUpdate: (d) =>
                  _tagDragKey.currentState?.updateDrag(d.globalPosition),
              onPanEnd: (d) =>
                  _tagDragKey.currentState?.endDrag(d.globalPosition),
              onPanCancel: () => _tagDragKey.currentState?.cancelDrag(),
              onLongPress: currentMedia != null
                  ? () => _tagDragKey.currentState?.openPinned()
                  : null,
              child: _BottomBarButton(
                icon: const IconData(0xe63e, fontFamily: "iconfont"),
                label: "标签",
                onPressed: currentMedia != null
                    ? () => _openLabelPage(context, currentMedia.id)
                    : null,
              ),
            ),
            // 网格视图 / 捆绑
            _BottomBarButton(
              icon: const IconData(0xe604, fontFamily: "iconfont"),
              label: inGroup ? '组内总览' : '网格',
              onPressed: () => _openGridView(context),
            ),
            if (inGroup || groupSize > 1)
              _BottomBarButton(
                icon: inGroup
                    ? Icons.layers_clear_outlined
                    : Icons.layers_outlined,
                label: inGroup ? '退出分组' : '组内 $groupSize 项',
                color: Colors.amber,
                onPressed: inGroup
                    ? () => ref
                          .read(currentMediaAssetProvider.notifier)
                          .closeGroup()
                    : () => _browseGroup(currentMedia!),
              ),
            // 删除当前媒体文件
            _BottomBarButton(
              icon: const IconData(0xe649, fontFamily: "iconfont"),
              label: currentMedia?.isDeleted == true
                  ? '恢复'
                  : inGroup && currentMedia?.groupId == null
                  ? '删除整组'
                  : '删除',
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
      MaterialPageRoute(builder: (_) => const MediasBrowserPage()),
    );
  }

  /// 切换删除状态
  Future<void> _toggleDelete(MediaAsset media) async {
    try {
      if (!media.isDeleted) {
        await ref.read(currentMediaAssetProvider.notifier).next();
      }
      await ref
          .read(mediaAssetListProvider.notifier)
          .markDeleted(media.id, deleted: !media.isDeleted);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$error')));
      }
    }
  }

  /// 打开详情页面
  Future<void> _openDetailPage(BuildContext context) async {
    final currentMedia = ref.read(currentMediaAssetProvider);
    if (currentMedia == null) return;

    final target = await Navigator.push<MediaAsset>(
      context,
      MaterialPageRoute(builder: (_) => MediaDetailPage(asset: currentMedia)),
    );
    if (target != null && mounted) await _browseGroup(target);
  }

  Future<void> _browseGroup(MediaAsset asset) async {
    try {
      await ref.read(currentMediaAssetProvider.notifier).browseGroup(asset);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('分组加载失败：$error')));
      }
    }
  }

  /// 打开编辑页面
  void _openEditor(BuildContext context, MediaAsset media) {
    if (media.isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ImageEditorPage(asset: media)),
      );
    } else if (media.isVideo) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VideoTrimmerPage(asset: media)),
      );
    }
  }

  /// 跳转到上一张（自动跳过已删除）
  void _goToPrevious() {
    ref.read(currentMediaAssetProvider.notifier).previous();
  }

  /// 跳转到下一张（自动跳过已删除）
  void _goToNext() {
    ref.read(currentMediaAssetProvider.notifier).next();
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
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width / 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: effectiveColor, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: effectiveColor, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
