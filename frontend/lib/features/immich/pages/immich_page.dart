import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/chat/chat_entry.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/models/tag.dart';
import 'package:torrid/features/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/immich/providers/immich_ops_providers.dart';
import 'package:torrid/features/immich/providers/immich_providers.dart';
import 'package:torrid/features/immich/widgets/immich_ai_tag_sheet.dart';
import 'package:torrid/features/immich/widgets/immich_dialogs.dart';
import 'package:torrid/features/immich/widgets/immich_media_grid.dart';
import 'package:torrid/features/immich/widgets/immich_ops_sheet.dart';
import 'package:torrid/features/immich/widgets/immich_tag_tree.dart';
import 'package:torrid/features/shared/media_viewer_page.dart';

/// 相册页 (immich)
///
/// 始终在线的媒体/标签管理页: 数据直连局域网后端, 同时把结果镜像回本地缓存。
/// - 标签树 (Drawer): 浏览/筛选/新建/重命名/移动/删除/快捷标签
/// - AI 标签 (只读): 由服务端 VLM 自动生成, 仅用于筛选与查看, 不与人工标签混淆
/// - 媒体网格: 分页浏览, 多选批量加标签/移除标签/删除/恢复/备注/捆绑/解绑
/// - 单张媒体: 全屏查看 (缩放/播放) + 详情面板编辑备注与标签
class ImmichPage extends ConsumerStatefulWidget {
  const ImmichPage({super.key});

  @override
  ConsumerState<ImmichPage> createState() => _ImmichPageState();
}

class _ImmichPageState extends ConsumerState<ImmichPage> {
  @override
  void initState() {
    super.initState();
    // 服务端为权威: 进入页面时同步一次标签 (失败则继续用本地缓存)
    Future.microtask(() async {
      try {
        await ref.read(tagTreeProvider.notifier).syncFromServer();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(immichMediaProvider);
    final page = mediaAsync.valueOrNull;
    final selection = ref.watch(immichSelectionProvider);
    final busy = ref.watch(immichActionsProvider);
    final selectionMode = ref.watch(immichOpsProvider).selectionMode;
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final tagById = {for (final tag in tags) tag.id: tag};

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('相册'),
            if (page != null)
              Text(
                '${page.total} 项',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: '同步',
            onPressed: _sync,
          ),
          IconButton(
            icon: Icon(selectionMode ? Icons.close : Icons.checklist),
            tooltip: selectionMode ? '退出多选' : '多选',
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
      drawer: const ImmichTagTreePanel(),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _buildBody(
              mediaAsync,
              page,
              selection,
              tagById,
              selectionMode,
            ),
          ),
        ],
      ),
      bottomNavigationBar: selection.isEmpty
          ? null
          : ImmichSelectionBar(
              count: selection.length,
              onAddTags: () => _startBatchOp(ImmichBatchOp.addTags),
              onRemoveTags: () => _startBatchOp(ImmichBatchOp.removeTags),
              onDelete: () => _startBatchOp(ImmichBatchOp.delete),
              onRestore: () => _startBatchOp(ImmichBatchOp.restore),
              onMessage: () => _startBatchOp(ImmichBatchOp.message),
              onBundle: () => _startBatchOp(ImmichBatchOp.bundle),
              onUnbundle: () => _startBatchOp(ImmichBatchOp.unbundle),
              onClear: () =>
                  ref.read(immichOpsProvider.notifier).clearSelection(),
            ),
    );
  }

  // 筛选栏

  Widget _buildFilterBar() {
    final filter = ref.watch(immichFilterNotifierProvider);
    final notifier = ref.read(immichFilterNotifierProvider.notifier);
    final tags = ref.watch(tagTreeProvider).valueOrNull ?? const <Tag>[];
    final byId = {for (final tag in tags) tag.id: tag};
    final favorites = ref.watch(favoriteTagsProvider);
    final total = ref.watch(immichMediaProvider).valueOrNull?.total;
    final active = filter.tagIds.isNotEmpty ||
        filter.untagged ||
        filter.includeDeleted ||
        filter.vlmTags.isNotEmpty ||
        !filter.includeDescendants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行: 条件开关 + 结果数
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              FilterChip(
                label: const Text('未打标签', style: TextStyle(fontSize: 12)),
                selected: filter.untagged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (_) => notifier.toggleUntagged(),
              ),
              if (filter.tagIds.isNotEmpty) ...[
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('含子标签', style: TextStyle(fontSize: 12)),
                  selected: filter.includeDescendants,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: notifier.setIncludeDescendants,
                ),
              ],
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('含已删除', style: TextStyle(fontSize: 12)),
                selected: filter.includeDeleted,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: notifier.setIncludeDeleted,
              ),
              const SizedBox(width: 8),
              Text(
                total == null ? '加载中…' : '共 $total 项',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: notifier.reset,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('清空', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),

        // 第二行: 已选标签（可单个移除）
        if (filter.tagIds.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                for (final id in filter.tagIds) ...[
                  Tooltip(
                    message: byId[id]?.fullPath ?? '',
                    child: InputChip(
                      label: Text(
                        byId[id]?.name ?? '未知标签',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onDeleted: () => notifier.toggleTag(id),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

        // 第三行: 快捷标签一键筛选
        if (favorites.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
            child: Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                const SizedBox(width: 4),
                for (final tag in favorites) ...[
                  FilterChip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                    selected: filter.tagIds.contains(tag.id),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onSelected: (_) => notifier.toggleTag(tag.id),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),

        // 第四行: AI 标签 (只读, 服务端 VLM 自动生成, 与人工标签分开呈现)
        _buildAiTagRow(filter, notifier),
      ],
    );
  }

  /// AI 标签筛选入口；没有可用 AI 标签时整行不出现。
  ///
  /// 只保留一个入口按钮 + 已选条件，完整列表（可搜索、带次数）在弹出面板里，
  /// 避免把几十个标签塞进筛选栏挤占空间。
  Widget _buildAiTagRow(ImmichFilter filter, ImmichFilterNotifier notifier) {
    final aiTags = ref.watch(immichAiTagsProvider).valueOrNull;
    if (aiTags == null || aiTags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => showImmichAiTagSheet(context),
                icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.teal),
                tooltip: 'AI 标签筛选',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(width: 2),
              Text(
                'AI 标签',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: () => showImmichAiTagSheet(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  filter.vlmTags.isEmpty
                      ? '筛选（${aiTags.length} 个）'
                      : '已选 ${filter.vlmTags.length} 个 · 修改',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          // 已选 AI 标签单独一行，明确它们与人工标签筛选互不影响
          if (filter.vlmTags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final tag in filter.vlmTags)
                  InputChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.auto_awesome, size: 14),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onDeleted: () => notifier.toggleVlmTag(tag),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // 主体

  Widget _buildBody(
    AsyncValue<ImmichMediaPage> mediaAsync,
    ImmichMediaPage? page,
    Set<String> selection,
    Map<String, Tag> tagById,
    bool selectionMode,
  ) {
    if (page == null) {
      return mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '加载失败: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(immichMediaProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }

    if (page.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('没有符合条件的媒体',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(immichFilterNotifierProvider.notifier).reset();
                ref.invalidate(immichMediaProvider);
              },
              child: const Text('清除筛选'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ImmichMediaGrid(
          page: page,
          tagById: tagById,
          selectionMode: selectionMode,
          selectedIds: selection,
          selectionOrder: selection.toList(),
          onLoadMore: _loadMore,
          onRefresh: _refresh,
          onTap: _onTapAsset,
          onLongPress: _onLongPressAsset,
        ),
        if (mediaAsync.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  // 基础交互

  Future<void> _sync() async {
    try {
      await ref.read(tagTreeProvider.notifier).syncFromServer();
      await ref.read(immichMediaProvider.notifier).refresh();
      _snack('已同步');
    } catch (e) {
      _snack('同步失败: $e');
    }
  }

  Future<void> _refresh() async {
    try {
      await ref.read(immichMediaProvider.notifier).refresh();
    } catch (e) {
      _snack('刷新失败: $e');
    }
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(immichMediaProvider.notifier).loadMore();
    } catch (e) {
      _snack('加载更多失败: $e');
    }
  }

  void _toggleSelectionMode() {
    ref.read(immichOpsProvider.notifier).toggleSelectionMode();
  }

  void _onTapAsset(MediaAsset asset) {
    if (ref.read(immichOpsProvider).selectionMode) {
      ref.read(immichSelectionProvider.notifier).toggle(asset.id);
      return;
    }
    _openViewer(asset.id);
  }

  /// 打开全屏查看器；管理入口（备注/人工标签/删除）作为右上角操作注入。
  void _openViewer(String mediaId) {
    final assets = ref.read(immichMediaProvider).valueOrNull?.assets ?? const [];
    final index = assets.indexWhere((item) => item.id == mediaId);
    if (index < 0) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewerPage(
          assets: assets,
          initialIndex: index,
          actions: (viewerContext, asset) => [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: '问问AI',
              onPressed: () {
                Navigator.of(viewerContext).pop();
                askAiAboutMedia(
                  context,
                  mediaId: asset.id,
                  fileName: asset.filePath.split(RegExp(r'[/\\]')).last,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: '详情与标签',
              onPressed: () => showImmichMediaDetail(
                viewerContext,
                mediaId: asset.id,
                fallback: asset,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLongPressAsset(MediaAsset asset) {
    ref.read(immichOpsProvider.notifier).longPressAsset(asset.id);
  }

  // 批量操作

  /// 入口: 由流程层决定是否需要弹窗, 页面只负责呈现并把输入回填
  Future<void> _startBatchOp(ImmichBatchOp op) async {
    final ops = ref.read(immichOpsProvider.notifier);
    final request = await ops.start(op);
    if (!mounted) return;

    if (request != null) {
      await _presentRequest(request);
      if (!mounted) return;
    }
    _report(ref.read(immichOpsProvider).outcome);
  }

  /// 按请求呈现对应弹窗 (控件与文案都在页面层); 关闭弹窗视为放弃本次操作
  Future<void> _presentRequest(ImmichOpRequest request) async {
    final ops = ref.read(immichOpsProvider.notifier);
    switch (request) {
      case ImmichTagPickRequest(:final op, :final restrictTo):
        final picked = await showImmichTagPicker(
          context,
          title: op == ImmichBatchOp.removeTags ? '移除标签' : '添加标签',
          restrictTo: restrictTo,
        );
        if (picked == null) {
          ops.cancel();
          return;
        }
        await ops.submit(ImmichTagsAnswer(picked));
      case ImmichConfirmRequest(:final mediaIds):
        final confirmed = await showImmichConfirmDialog(
          context,
          title: '删除媒体',
          message: '确定软删除选中的 ${mediaIds.length} 项吗?',
          confirmText: '删除',
          danger: true,
        );
        if (!confirmed) {
          ops.cancel();
          return;
        }
        await ops.submit(const ImmichConfirmedAnswer());
      case ImmichMessageRequest(
          :final mediaIds,
          :final initial,
          :final uniform,
        ):
        final text = await showImmichTextDialog(
          context,
          title: '编辑备注 (${mediaIds.length} 项)',
          initial: initial,
          label: '备注',
          hint: uniform ? '留空即清除备注' : '多项备注不同, 输入将覆盖为同一备注',
          maxLines: 3,
        );
        if (text == null) {
          ops.cancel();
          return;
        }
        await ops.submit(ImmichMessageAnswer(text));
      case ImmichLeadPickRequest(:final assets):
        final leadId = await showImmichLeadPicker(context, assets);
        if (leadId == null) {
          ops.cancel();
          return;
        }
        await ops.submit(ImmichLeadAnswer(leadId));
    }
  }

  /// 把流程层的操作结果翻成提示文案
  void _report(ImmichOpOutcome? outcome) {
    switch (outcome) {
      case null:
        return;
      case ImmichOpRejected(:final reason):
        _snack(switch (reason) {
          ImmichOpRejection.noTags => '选中的媒体没有标签',
          ImmichOpRejection.tooFewForBundle => '请至少选择两个媒体',
        });
      case ImmichOpFailure(:final error):
        _snack('操作失败: $error');
      case ImmichOpSuccess(:final op, :final affected):
        _snack(switch (op) {
          ImmichBatchOp.addTags => '已为 $affected 项添加标签',
          ImmichBatchOp.removeTags => '已移除标签',
          ImmichBatchOp.delete => '已删除 $affected 项',
          ImmichBatchOp.restore => '已恢复 $affected 项',
          ImmichBatchOp.message => '备注已更新',
          ImmichBatchOp.bundle => '已捆绑 $affected 项',
          ImmichBatchOp.unbundle => '已解绑 $affected 项',
        });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}
