import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/pages/label_list_page.dart';
import 'package:torrid/features/others/gallery/pages/media_detail_page.dart';
import 'package:torrid/features/others/gallery/pages/medias_gridview_page.dart';
import 'package:torrid/features/others/gallery/pages/setting_page.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/content_widget.dart';

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

  /// 切换工具栏可见性
  void _toggleBarsVisibility() {
    setState(() {
      _barsVisible = !_barsVisible;
    });
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

    // 计算安全区域高度，用于手势区域排除
    final mediaQuery = MediaQuery.of(context);
    final topBarHeight = mediaQuery.padding.top + 44; // SafeArea + 紧凑顶部栏
    final bottomBarHeight = mediaQuery.padding.bottom + 56 + 40; // SafeArea + BottomBar + TagBar

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏内容区 - ContentWidget 覆盖整个屏幕
          Positioned.fill(
            child: ContentWidget(
              onToggleBars: _toggleBarsVisibility,
              onPrevious: _goToPrevious,
              onNext: _goToNext,
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
        ],
      ),
    );
  }

  /// 构建顶部导航栏
  Widget _buildTopBar(BuildContext context) {
    final currentMedia = ref.watch(currentMediaAssetProvider);
    final fileName = currentMedia?.filePath.split('/').last.split('\\').last ?? '';
    
    return Container(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              // 返回按钮
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                tooltip: "返回",
              ),
              // 文件名 (占据中间空间)
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              // 设置按钮
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
      // 先跳转到下一个未删除的文件，再标记删除
      // 这样 UI 会先显示下一张，不会闪烁 loading 状态
      await ref.read(currentMediaAssetProvider.notifier).next();
      
      // 标记删除（乐观更新，无 loading）
      await ref
          .read(mediaAssetListProvider.notifier)
          .markDeleted(media.id, deleted: true);
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
