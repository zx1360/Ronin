part of '../../pages/medias_browser_page.dart';

extension _BrowserLayouts on _MediasBrowserPageState {
  Widget _buildMediaGrid(
    List<MediaAsset> assets,
    int columns,
    GalleryGridPreviewMode mode,
    MediaAsset? currentMedia,
    Set<String> taggedIds,
    Map<String, GalleryPreview> previews,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gridWidth = constraints.maxWidth - 4;
        final key = (assets, columns, mode, _gridWidth, previews);
        if (mode != GalleryGridPreviewMode.thumb && _layoutKey != key) {
          _layoutKey = key;
          _previewLayout = MediaGridLayout(
            aspectRatios: [
              for (final asset in assets) previews[asset.id]?.aspectRatio ?? 1,
            ],
            columns: columns,
            width: _gridWidth,
            waterfall: mode == GalleryGridPreviewMode.waterfall,
            reverseCrossAxis: Directionality.of(context) == TextDirection.rtl,
          );
        }
        _performInitialScrollIfNeeded();
        final selectionIndices = {
          for (var i = 0; i < _selectionOrder.length; i++)
            _selectionOrder[i]: i + 1,
        };
        return GridView.builder(
          key: ValueKey((mode, columns)),
          controller: _scrollController,
          padding: const EdgeInsets.all(2),
          gridDelegate: mode == GalleryGridPreviewMode.thumb
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                )
              : MediaGridDelegate(_previewLayout!),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return _GridTile(
              key: ValueKey(asset.id),
              asset: asset,
              usePreview: mode != GalleryGridPreviewMode.thumb,
              previewPath: previews[asset.id]?.path,
              isSelected: _selectedIds.contains(asset.id),
              isCurrent: currentMedia?.id == asset.id,
              selectionIndex: selectionIndices[asset.id],
              isSelectionMode: _isSelectionMode,
              hasTags: taggedIds.contains(asset.id),
              onTap: () => _handleTap(asset, index),
              onLongPress: () => _handleLongPress(asset),
            );
          },
        );
      },
    );
  }
}
