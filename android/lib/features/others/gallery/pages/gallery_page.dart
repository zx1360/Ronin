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

String? _editSummary(MediaAsset media) {
  final params = media.editParams;
  if (params == null) return null;
  try {
    final json = jsonDecode(params) as Map<String, dynamic>;
    final type = json['type'] as String?;
    if (type == 'image') {
      final rot = json['rotation'] as int? ?? 0;
      final hasCrop = json['crop_left'] != null;
      final parts = <String>[];
      if (rot != 0) parts.add('旋转$rot°');
      if (hasCrop) parts.add('已裁切');
      return parts.isEmpty ? null : parts.join(' · ');
    } else if (type == 'video') {
      final start = (json['trim_start_sec'] as num?)?.toDouble();
      final end = (json['trim_end_sec'] as num?)?.toDouble();
      final parts = <String>[];
      if (start != null && start > 0) parts.add(_formatSeconds(start));
      if (end != null && end > 0) parts.add(_formatSeconds(end));
      return parts.isEmpty ? null : '剪辑 ${parts.join(' → ')}';
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
  static const _barBackgroundColor = Color(0x40000000);
  static const _bottomBarHeight = 56.0;
  static const _tagBarHeight = 40.0;
  static const _playbackControlsClearance = 88.0;

  bool _barsVisible = true;

  /// 旋转角度 (0, 1, 2, 3 表示 0°, 90°, 180°, 270°)
  int _quarterTurns = 0;
  String? _ratioMediaId;
  double? _aspectRatio;
  String? _manualMediaId;

  /// 拖拽打标签浮层控制器（由"标签"按钮手势驱动）
  final GlobalKey<TagDragOverlayState> _tagDragKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ref.read(galleryWriteBufferProvider).retry();
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
    try {
      await ref
          .read(galleryAutoOrientationProvider.notifier)
          .update(!ref.read(galleryAutoOrientationProvider));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('方向设置保存失败：$error')));
      }
      return;
    }
    if (!mounted) return;
    _manualMediaId = null;
    if (_ratioMediaId != null && _aspectRatio != null) {
      _onAspectRatio(_ratioMediaId!, _aspectRatio!);
    }
  }

  @override
  Widget build(BuildContext context) {
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

    final showBars =
        _barsVisible || currentMedia == null || currentMedia.isDeleted;
    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        (showBars
            ? _bottomBarHeight + (currentMedia == null ? 0 : _tagBarHeight)
            : 0);

    return PopScope(
      canPop: !inGroup,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inGroup) {
          ref.read(currentMediaAssetProvider.notifier).closeGroup();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
        ),
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
                  bottomInset: bottomInset,
                ),
              ),
              if (showBars)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (currentMedia != null)
                          _buildTagBar(currentTags.value ?? []),
                        _buildBottomBar(context, currentMedia, inGroup),
                      ],
                    ),
                  ),
                ),
              if (ref.watch(galleryPreviewWindowEnabledProvider))
                PreviewWindowWidget(
                  onTap: _goToNext,
                  rotationQuarterTurns: _quarterTurns,
                  minBottom:
                      bottomInset +
                      (currentMedia?.isVideo == true && _quarterTurns.isEven
                          ? _playbackControlsClearance
                          : 8),
                ),
              Positioned.fill(
                child: TagDragOverlay(
                  key: _tagDragKey,
                  bottomInset: showBars ? bottomInset : 8,
                  quarterTurns: _quarterTurns,
                ),
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
      return const SizedBox(
        height: _tagBarHeight,
        child: Center(
          child: Text(
            '暂无标签',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      height: _tagBarHeight,
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
  Widget _buildBottomBar(
    BuildContext context,
    MediaAsset? currentMedia,
    bool inGroup,
  ) {
    final groupSize =
        ref.watch(mediaGroupSizesProvider).value?[currentMedia?.groupId ??
            currentMedia?.id] ??
        0;
    final buttons = [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: currentMedia != null
            ? (d) => _tagDragKey.currentState?.startDrag(d.globalPosition)
            : null,
        onPanUpdate: (d) =>
            _tagDragKey.currentState?.updateDrag(d.globalPosition),
        onPanEnd: (d) => _tagDragKey.currentState?.endDrag(d.globalPosition),
        onPanCancel: () => _tagDragKey.currentState?.cancelDrag(),
        onLongPress: currentMedia != null
            ? () => _tagDragKey.currentState?.openPinned()
            : null,
        child: _bottomButton(
          const IconData(0xe63e, fontFamily: 'iconfont'),
          '标签',
          currentMedia != null
              ? () => _openLabelPage(context, currentMedia.id)
              : null,
        ),
      ),
      _bottomButton(
        const IconData(0xe604, fontFamily: 'iconfont'),
        inGroup ? '组内总览' : '网格',
        () => _openGridView(context),
      ),
      if (inGroup || groupSize > 1)
        _bottomButton(
          inGroup ? Icons.layers_clear_outlined : Icons.layers_outlined,
          inGroup ? '退出分组' : '组内 $groupSize 项',
          inGroup
              ? ref.read(currentMediaAssetProvider.notifier).closeGroup
              : () => _browseGroup(currentMedia!),
          color: Colors.amber,
        ),
      _bottomButton(
        const IconData(0xe649, fontFamily: 'iconfont'),
        currentMedia?.isDeleted == true
            ? '恢复'
            : inGroup && currentMedia?.groupId == null
            ? '删除整组'
            : '删除',
        currentMedia != null ? () => _toggleDelete(currentMedia) : null,
        color: currentMedia?.isDeleted == true ? Colors.red : Colors.white,
      ),
      PopupMenuButton<void>(
        tooltip: '更多',
        popUpAnimationStyle: AnimationStyle.noAnimation,
        borderRadius: BorderRadius.circular(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        constraints: const BoxConstraints(minWidth: 248, maxWidth: 288),
        itemBuilder: _buildMoreMenu,
        child: const _BottomBarLabel(
          icon: Icons.more_horiz_rounded,
          label: '更多',
        ),
      ),
    ];
    return Material(
      color: _barBackgroundColor,
      child: SizedBox(
        height: _bottomBarHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final button in buttons) Expanded(child: button)],
        ),
      ),
    );
  }

  Widget _bottomButton(
    IconData icon,
    String label,
    VoidCallback? onPressed, {
    Color color = Colors.white,
  }) => InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(8),
    child: _BottomBarLabel(
      icon: icon,
      label: label,
      color: onPressed == null ? Colors.white38 : color,
    ),
  );

  List<PopupMenuEntry<void>> _buildMoreMenu(BuildContext menuContext) {
    final media = ref.read(currentMediaAssetProvider);
    final inGroup = ref.read(galleryActiveGroupProvider) != null;
    final total = ref.read(galleryBrowsingAssetsProvider).value?.length ?? 0;
    final position = ref.read(galleryBrowsingIndexProvider) + 1;
    final autoOrientation = ref.read(galleryAutoOrientationProvider);
    final theme = Theme.of(menuContext);
    final colors = theme.colorScheme;
    final editSummary = media == null ? null : _editSummary(media);
    return [
      if (media != null) ...[
        PopupMenuItem<void>(
          enabled: false,
          height: 0,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                media.filePath.split('/').last.split('\\').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                ),
              ),
              if (editSummary != null)
                Text(editSummary, style: theme.textTheme.bodySmall),
              if (position > 0 && position <= total) ...[
                const SizedBox(height: 10),
                Text(
                  '${inGroup ? (media.isGroupLead ? '组内主文件' : '组内成员') : '浏览进度'}'
                  ' · $position / $total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: position / total,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                  semanticsLabel: '媒体浏览进度',
                  semanticsValue: '第 $position 项，共 $total 项',
                ),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        _moreMenuItem(Icons.info_outline, '详情', () => _openMediaAction(media)),
        if (!media.isDeleted && (media.isImage || media.isVideo))
          _moreMenuItem(
            media.isVideo ? Icons.content_cut : Icons.crop,
            media.isVideo ? '剪辑视频' : '裁切图片',
            () => _openMediaAction(media, edit: true),
          ),
      ],
      CheckedPopupMenuItem<void>(
        checked: autoOrientation,
        onTap: _toggleAutoOrientation,
        child: const Text('自动匹配媒体方向'),
      ),
      _moreMenuItem(Icons.settings_outlined, '媒体管理设置', () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const GallerySettingPage()));
      }),
    ];
  }

  PopupMenuItem<void> _moreMenuItem(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) => PopupMenuItem<void>(
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 16),
        Flexible(child: Text(label)),
      ],
    ),
  );

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

  Future<void> _openMediaAction(MediaAsset shown, {bool edit = false}) async {
    final media = ref.read(currentMediaAssetProvider);
    if (media == null ||
        media.id != shown.id ||
        media.localLibraryId != shown.localLibraryId ||
        (edit && (media.isDeleted || (!media.isImage && !media.isVideo)))) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前媒体已变化，请重新打开「更多」')));
      return;
    }
    final target = await Navigator.push<MediaAsset>(
      context,
      MaterialPageRoute(
        builder: (_) {
          if (!edit) return MediaDetailPage(asset: media);
          return media.isVideo
              ? VideoTrimmerPage(asset: media)
              : ImageEditorPage(asset: media);
        },
      ),
    );
    if (!edit && target != null && mounted) await _browseGroup(target);
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

  /// 跳转到上一张（自动跳过已删除）
  void _goToPrevious() {
    ref.read(currentMediaAssetProvider.notifier).previous();
  }

  /// 跳转到下一张（自动跳过已删除）
  void _goToNext() {
    ref.read(currentMediaAssetProvider.notifier).next();
  }
}

class _BottomBarLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BottomBarLabel({
    required this.icon,
    required this.label,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: TextStyle(color: color, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
