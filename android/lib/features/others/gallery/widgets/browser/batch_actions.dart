part of '../../pages/medias_browser_page.dart';

extension _BrowserBatchActions on _MediasBrowserPageState {
  /// 构建底部操作栏
  Widget _buildBottomBar() {
    if (_working) {
      return const SafeArea(
        child: SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final allAssets = ref.read(galleryBrowsingAssetsProvider).value ?? [];
    final byId = {for (final asset in allAssets) asset.id: asset};
    final selected = [
      for (final id in _selectionOrder)
        if (byId[id] != null) byId[id]!,
    ];
    final hasDeletedSelected = selected.any((asset) => asset.isDeleted);
    final hasNonDeletedSelected = selected.any((asset) => !asset.isDeleted);

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomButton(
              icon: Icons.share,
              label: '分享',
              onPressed: () => showMediaShareDialog(
                context,
                ref.read(apiClientManagerProvider),
                selected,
              ),
            ),
            // 捆绑按钮 (需要至少选择2个)
            if (_selectedIds.length >= 2 &&
                !hasDeletedSelected &&
                ref.read(galleryActiveGroupProvider) == null)
              _BottomButton(
                icon: Icons.link,
                label: '捆绑',
                onPressed: _bundleSelected,
              ),
            // 恢复按钮 (有已删除的选中项时显示)
            if (hasDeletedSelected)
              _BottomButton(
                icon: Icons.restore,
                label: '恢复',
                color: Colors.green,
                onPressed: _restoreSelected,
              ),
            // 删除按钮 (有未删除的选中项时显示)
            if (hasNonDeletedSelected)
              _BottomButton(
                icon: Icons.delete,
                label: '删除',
                color: Colors.red,
                onPressed: _deleteSelected,
              ),
          ],
        ),
      ),
    );
  }

  /// 处理点击

  Future<void> _bundleSelected() async {
    if (_working || _selectionOrder.length < 2) return;
    final byId = {
      for (final asset
          in ref.read(mediaAssetListProvider).value ?? <MediaAsset>[])
        asset.id: asset,
    };
    final selected = [
      for (final id in _selectionOrder)
        if (byId[id] != null) byId[id]!,
    ];
    if (selected.length < 2 || selected.any((a) => a.isDeleted)) return;
    var leadId = selected.first.id;
    final storage = ref.read(galleryStorageProvider);
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('选择分组主文件'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '列表中显示主文件，其他成员可在详情中查看。已有分组会合并，文件各自的标签、备注和编辑保持独立。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemExtent: 64,
                    itemCount: selected.length,
                    itemBuilder: (_, index) {
                      final asset = selected[index];
                      return ListTile(
                        selected: asset.id == leadId,
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: FutureBuilder<File?>(
                            future: asset.thumbPath == null
                                ? Future.value(null)
                                : storage.getThumbFile(asset.thumbPath!),
                            builder: (_, snapshot) => snapshot.data == null
                                ? Icon(
                                    asset.isVideo
                                        ? Icons.videocam
                                        : Icons.image,
                                  )
                                : Image.file(snapshot.data!, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          asset.filePath.split('/').last.split('\\').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          asset.id == leadId
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        onTap: () => update(() => leadId = asset.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, leadId),
              child: const Text('捆绑'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    await _runSelectionAction(
      () => ref
          .read(mediaAssetListProvider.notifier)
          .bundleMedia(
            chosen,
            selected.where((a) => a.id != chosen).map((a) => a.id).toList(),
          ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_working) return;
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('标记删除'),
        content: Text('标记删除所选 ${ids.length} 项及其组成员？后端执行清理前可以恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('标记删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runSelectionAction(() async {
      await ref.read(mediaAssetListProvider.notifier).batchMarkDeleted(ids);
    });
  }

  Future<void> _restoreSelected() async {
    final ids = _selectedIds.toList();
    await _runSelectionAction(() async {
      await ref
          .read(mediaAssetListProvider.notifier)
          .batchMarkDeleted(ids, deleted: false);
    });
  }
}
