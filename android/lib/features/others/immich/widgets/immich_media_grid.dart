import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:intl/intl.dart';
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
      return const _ThumbPlaceholder(
        icon: Icons.cloud_off_outlined,
        text: '未连接',
      );
    }
    return CachedNetworkImage(
      imageUrl: '${api.baseUrl}/API/gallery/${asset.id}/thumb',
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

class AlbumMediaGrid extends StatefulWidget {
  final List<MediaAsset> assets;
  final List<String> Function(MediaAsset)? tagsFor;
  final bool timeline;
  final bool selectionMode;
  final Set<String> selectedIds;
  final bool loadingMore;
  final bool autoLoadMore;
  final VoidCallback? onLoadMore;
  final Future<void> Function() onRefresh;
  final ValueChanged<MediaAsset> onTap;
  final ValueChanged<MediaAsset> onLongPress;

  const AlbumMediaGrid({
    super.key,
    required this.assets,
    this.tagsFor,
    this.timeline = true,
    required this.selectionMode,
    required this.selectedIds,
    this.loadingMore = false,
    this.autoLoadMore = true,
    this.onLoadMore,
    required this.onRefresh,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<AlbumMediaGrid> createState() => _AlbumMediaGridState();
}

class _AlbumMediaGridState extends State<AlbumMediaGrid> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (widget.autoLoadMore &&
          !widget.loadingMore &&
          _scroll.position.extentAfter < 400) {
        widget.onLoadMore?.call();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assets = widget.assets;
    final order = {
      for (final (index, id) in widget.selectedIds.indexed) id: index + 1,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 120).ceil().clamp(2, 6);
        final rows = <({DateTime? day, int start, int end})>[];
        var start = 0;
        while (start < assets.length) {
          final day = DateUtils.dateOnly(assets[start].capturedAt.toLocal());
          var end = assets.length;
          if (widget.timeline) {
            rows.add((day: day, start: start, end: start));
            end = start + 1;
            while (end < assets.length &&
                DateUtils.isSameDay(day, assets[end].capturedAt.toLocal())) {
              end++;
            }
          }
          while (start < end) {
            final next = (start + columns).clamp(start, end);
            rows.add((day: null, start: start, end: next));
            start = next;
          }
        }
        final hasFooter = widget.onLoadMore != null || widget.loadingMore;
        return RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: Scrollbar(
            controller: _scroll,
            interactive: true,
            child: ListView.builder(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
              itemCount: rows.length + (hasFooter ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == rows.length) {
                  return Center(
                    child: widget.loadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          )
                        : TextButton(
                            onPressed: widget.onLoadMore,
                            child: const Text('加载更多'),
                          ),
                  );
                }
                final row = rows[index];
                if (row.day case final day?) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 7),
                    child: Semantics(
                      header: true,
                      child: Text(
                        DateFormat('yyyy年M月d日').format(day),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  );
                }
                return Row(
                  children: [
                    for (var i = row.start; i < row.start + columns; i++)
                      Expanded(
                        child: i < row.end
                            ? Padding(
                                padding: const EdgeInsets.all(1),
                                child: AspectRatio(
                                  aspectRatio: 1,
                                  child: _tile(assets[i], order),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _tile(MediaAsset asset, Map<String, int> order) => _MediaTile(
    asset: asset,
    tagNames: widget.tagsFor?.call(asset) ?? const [],
    selectionMode: widget.selectionMode,
    selected: order.containsKey(asset.id),
    selectionIndex: order[asset.id],
    onTap: () => widget.onTap(asset),
    onLongPress: () => widget.onLongPress(asset),
  );
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
                  const Icon(
                    Icons.play_circle_fill,
                    size: 16,
                    color: Colors.white70,
                  ),
                if (asset.isGroupMember)
                  const Icon(Icons.link, size: 14, color: Colors.white70),
                if (asset.isDeleted)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '待删除',
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
