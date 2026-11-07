import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 已知尺寸的单一 Sliver，等比行和瀑布流共用精确滚动坐标。
class MediaGridLayout extends SliverGridLayout {
  final List<SliverGridGeometry> _tiles = [];
  final List<double> _trailingOffsets = [];
  final double _extent;

  factory MediaGridLayout({
    required List<double> aspectRatios,
    required int columns,
    required double width,
    required bool waterfall,
    bool reverseCrossAxis = false,
    double spacing = 2,
  }) {
    final cellWidth = math.max(
      0.0,
      (width - spacing * (columns - 1)) / columns,
    );
    final heights = [
      for (final ratio in aspectRatios)
        cellWidth / (ratio.isFinite && ratio > 0 ? ratio : 1).clamp(0.25, 4.0),
    ];
    final tiles = <SliverGridGeometry>[];
    final offsets = List.filled(columns, 0.0);
    for (var start = 0; start < heights.length;) {
      if (waterfall) {
        var column = 0;
        for (var i = 1; i < columns; i++) {
          if (offsets[i] < offsets[column]) column = i;
        }
        tiles.add(
          SliverGridGeometry(
            scrollOffset: offsets[column],
            crossAxisOffset:
                (reverseCrossAxis ? columns - 1 - column : column) *
                (cellWidth + spacing),
            mainAxisExtent: heights[start],
            crossAxisExtent: cellWidth,
          ),
        );
        offsets[column] += heights[start] + spacing;
        start++;
      } else {
        final end = math.min(start + columns, heights.length);
        final rowHeight = heights.sublist(start, end).reduce(math.max);
        for (var i = start; i < end; i++) {
          final column = i - start;
          tiles.add(
            SliverGridGeometry(
              scrollOffset: offsets[0],
              crossAxisOffset:
                  (reverseCrossAxis ? columns - 1 - column : column) *
                  (cellWidth + spacing),
              mainAxisExtent: rowHeight,
              crossAxisExtent: cellWidth,
            ),
          );
        }
        offsets[0] += rowHeight + spacing;
        start = end;
      }
    }
    final extent = tiles.isEmpty ? 0.0 : offsets.reduce(math.max) - spacing;
    return MediaGridLayout._(tiles, extent);
  }

  MediaGridLayout._(List<SliverGridGeometry> tiles, this._extent) {
    var trailing = 0.0;
    for (final tile in tiles) {
      _tiles.add(tile);
      trailing = math.max(trailing, tile.trailingScrollOffset);
      _trailingOffsets.add(trailing);
    }
  }

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) => _tiles[index];

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) {
    var low = 0, high = _tiles.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_trailingOffsets[mid] <= scrollOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return math.min(low, math.max(0, _tiles.length - 1));
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) {
    var low = 0, high = _tiles.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_tiles[mid].scrollOffset < scrollOffset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return math.max(0, low - 1);
  }

  @override
  double computeMaxScrollOffset(int childCount) => _extent;
}

class MediaGridDelegate extends SliverGridDelegate {
  final MediaGridLayout layout;

  const MediaGridDelegate(this.layout);

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) => layout;

  @override
  bool shouldRelayout(MediaGridDelegate oldDelegate) =>
      oldDelegate.layout != layout;
}
