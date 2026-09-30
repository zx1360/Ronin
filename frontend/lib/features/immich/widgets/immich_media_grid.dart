import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/api/generated/api_contract.dart' show ApiPath;
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/tag.dart';
import 'package:torrid/features/immich/providers/immich_providers.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 服务端缩略图 (始终在线, 直连局域网后端并附带 API Key)
class ImmichThumb extends ConsumerWidget {
  final MediaAsset asset;
  final BoxFit fit;

  const ImmichThumb({super.key, required this.asset, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientManagerProvider);
    if (api.baseUrl.isEmpty) {
      return const _ThumbPlaceholder(icon: Icons.cloud_off_outlined, text: '未连接');
    }
    return CachedNetworkImage(
      imageUrl: '${api.baseUrl}${ApiPath.galleryIdTypePath(asset.id, 'thumb')}',
      httpHeaders: api.headers,
      fit: fit,
      placeholder: (context, url) => const ColoredBox(color: Colors.black12),
      errorWidget: (context, url, error) => _ThumbPlaceholder(
        icon: asset.isVideo
            ? Icons.videocam_off_outlined
            : Icons.broken_image_outlined,
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  final IconData icon;
  final String? text;

  const _ThumbPlaceholder({required this.icon, this.text});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black12,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: Colors.black26),
            if (text != null)
              Text(
                text!,
                style: const TextStyle(fontSize: 10, color: Colors.black38),
              ),
          ],
        ),
      ),
    );
  }
}

/// 媒体缩略图网格 (分页"加载更多")
class ImmichMediaGrid extends StatelessWidget {
  final ImmichMediaPage page;
  final Map<String, Tag> tagById;
  final bool selectionMode;
  final Set<String> selectedIds;

  /// 选中顺序 (用于展示序号, 首位为捆绑主文件)
  final List<String> selectionOrder;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final void Function(MediaAsset asset) onTap;
  final void Function(MediaAsset asset) onLongPress;

  const ImmichMediaGrid({
    super.key,
    required this.page,
    required this.tagById,
    required this.selectionMode,
    required this.selectedIds,
    required this.selectionOrder,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showMoreTile = page.hasMore;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (page.hasMore &&
              !page.loadingMore &&
              notification.metrics.extentAfter < 400) {
            onLoadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: page.assets.length + (showMoreTile ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= page.assets.length) {
              return _buildLoadMoreTile(context);
            }
            final asset = page.assets[index];
            final tagNames = [
              for (final id in page.tagIdsByMedia[asset.id] ?? const <String>[])
                if (tagById[id] != null) tagById[id]!.name,
            ];
            final orderIndex = selectionOrder.indexOf(asset.id);
            return _MediaTile(
              asset: asset,
              tagNames: tagNames,
              selectionMode: selectionMode,
              selected: selectedIds.contains(asset.id),
              selectionIndex: orderIndex >= 0 ? orderIndex + 1 : null,
              onTap: () => onTap(asset),
              onLongPress: () => onLongPress(asset),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadMoreTile(BuildContext context) {
    if (page.loadingMore) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return InkWell(
      onTap: onLoadMore,
      child: Center(
        child: Text(
          '加载更多',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaAsset asset;
  final List<String> tagNames;
  final bool selectionMode;
  final bool selected;
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaTile({
    required this.asset,
    required this.tagNames,
    required this.selectionMode,
    required this.selected,
    required this.selectionIndex,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImmichThumb(asset: asset),
          if (asset.isDeleted)
            ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          // 右上角状态角标
          Positioned(
            top: 3,
            right: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (asset.isVideo)
                  const Icon(Icons.play_circle_fill,
                      size: 16, color: Colors.white70),
                if (asset.isGroupMember)
                  const Icon(Icons.link, size: 14, color: Colors.white70),
                if (asset.isDeleted)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '已删除',
                      style: TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          // 左上角选中标记
          if (selectionMode || selected)
            Positioned(
              top: 3,
              left: 3,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : Colors.black38,
                  border: Border.all(color: Colors.white70, width: 1.5),
                ),
                child: selected
                    ? Text(
                        '${selectionIndex ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          // 底部标签名 (最多 2 个)
          if (tagNames.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(3, 6, 3, 2),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final name in tagNames.take(2))
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    if (tagNames.length > 2)
                      Text(
                        '+${tagNames.length - 2}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white70,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
