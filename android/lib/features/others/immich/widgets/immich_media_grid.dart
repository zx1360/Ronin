import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/services/gallery_api_service.dart';
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
      imageUrl: galleryMediaUrl(api.baseUrl, asset, type: 'thumb'),
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
  final List<String> Function(MediaAsset)? labelsFor;
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
    this.labelsFor,
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
  int _columns = 0;
  var _rows = <({DateTime? day, int start, int end})>[];

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
  void didUpdateWidget(covariant AlbumMediaGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.assets, widget.assets) ||
        oldWidget.timeline != widget.timeline) {
      _columns = 0;
    }
  }

  void _layoutRows(int columns) {
    if (_columns == columns) return;
    _columns = columns;
    final assets = widget.assets;
    _rows = [];
    var start = 0;
    while (start < assets.length) {
      var end = assets.length;
      if (widget.timeline) {
        final day = DateUtils.dateOnly(assets[start].capturedAt.toLocal());
        _rows.add((day: day, start: start, end: start));
        end = start + 1;
        while (end < assets.length &&
            DateUtils.isSameDay(day, assets[end].capturedAt.toLocal())) {
          end++;
        }
      }
      while (start < end) {
        final next = (start + columns).clamp(start, end);
        _rows.add((day: null, start: start, end: next));
        start = next;
      }
    }
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
        _layoutRows(columns);
        final rows = _rows;
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
                        '${day.year}年${day.month}月${day.day}日',
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
    labels: widget.labelsFor?.call(asset) ?? const [],
    selectionMode: widget.selectionMode,
    selected: order.containsKey(asset.id),
    selectionIndex: order[asset.id],
    onTap: () => widget.onTap(asset),
    onLongPress: () => widget.onLongPress(asset),
  );
}

class _MediaTile extends StatelessWidget {
  final MediaAsset asset;
  final List<String> labels;
  final bool selectionMode;
  final bool selected;
  final int? selectionIndex;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaTile({
    required this.asset,
    required this.labels,
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
                if (asset.isVideo || asset.isGroupMember)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppTheme.mediaOverlay,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (asset.isVideo)
                          const Icon(
                            Icons.play_circle_fill,
                            size: 14,
                            color: Colors.white,
                          ),
                        if (asset.isGroupMember)
                          const Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.white,
                            semanticLabel: '捆绑成员',
                          ),
                      ],
                    ),
                  ),
                if (asset.isDeleted)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '待删除',
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onErrorContainer,
                      ),
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
          if (labels.isNotEmpty)
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
                    for (final name in labels.take(2))
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
                    if (labels.length > 2)
                      Text(
                        '+${labels.length - 2}',
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
