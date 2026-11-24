import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/album/models/ai_search_models.dart';
import 'package:torrid/features/album/providers/album_providers.dart';
import 'package:torrid/features/album/services/ai_api_service.dart';
import 'package:torrid/features/album/widgets/album_dialogs.dart';
import 'package:torrid/features/album/widgets/review_thumbnail.dart';
import 'package:torrid/features/gallery/models/media_asset.dart';
import 'package:torrid/features/gallery/widgets/media_viewer_page.dart';

Future<void> showAlbumRelatedMedia(BuildContext context, MediaAsset asset) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.78,
        child: SafeArea(child: _RelatedMediaSheet(asset: asset)),
      ),
    );

class _RelatedMediaSheet extends ConsumerStatefulWidget {
  const _RelatedMediaSheet({required this.asset});

  final MediaAsset asset;

  @override
  ConsumerState<_RelatedMediaSheet> createState() => _RelatedMediaSheetState();
}

class _RelatedMediaSheetState extends ConsumerState<_RelatedMediaSheet> {
  final _selected = <String>{};
  CancelToken? _token;
  late Future<AiSearchResult> _result = _load();
  bool _writing = false;
  Object? _writeError;

  Future<AiSearchResult> _load() {
    _token?.cancel();
    final token = _token = CancelToken();
    return ref.read(aiApiProvider).relatedMedia(widget.asset.id, token);
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  Future<void> _bundle() async {
    final ids = _selected.toList();
    final confirmed = await showAlbumConfirmDialog(
      context,
      title: '捆绑相关媒体',
      message: '将选中的 ${ids.length} 项加入当前文件所在的捆绑组？',
      confirmText: '捆绑',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _writing = true;
      _writeError = null;
    });
    try {
      await ref
          .read(albumActionsProvider.notifier)
          .bundle(
            widget.asset.groupId ?? widget.asset.id,
            ids,
            onlySelected: true,
          );
      if (mounted) {
        setState(() {
          _selected.clear();
          _result = _load();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _writeError = error);
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _writing || ref.watch(albumActionsProvider);
    return Column(
      children: [
        Text('相关媒体', style: theme.textTheme.titleLarge),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text('查看已捆绑的文件，以及拍摄时间接近、画面相似的候选。'),
        ),
        if (_writeError case final error?)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              '$error',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        Expanded(
          child: FutureBuilder(
            future: _result,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: ListTile(
                    title: Text('${snapshot.error}'),
                    trailing: TextButton(
                      onPressed: () => setState(() => _result = _load()),
                      child: const Text('重试'),
                    ),
                  ),
                );
              }
              final hits = snapshot.data!.hits;
              if (hits.isEmpty) {
                return const Center(child: Text('暂无组员或关联候选'));
              }
              return ListView.builder(
                itemCount: hits.length,
                itemBuilder: (context, index) {
                  final hit = hits[index];
                  final bundled = hit.sources.contains('bundle');
                  final canBundle =
                      !bundled && !hit.sources.contains('other_bundle');
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox.square(
                        dimension: 52,
                        child: ReviewThumbnail(id: hit.id),
                      ),
                    ),
                    title: Text(
                      mediaFileName(hit.asset.filePath),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      bundled
                          ? '同一捆绑组'
                          : canBundle
                          ? '拍摄时间接近 · 画面相似'
                          : '已属于其他捆绑组',
                    ),
                    trailing: canBundle
                        ? Checkbox(
                            value: _selected.contains(hit.id),
                            onChanged: busy
                                ? null
                                : (selected) => setState(() {
                                    if (selected == true) {
                                      _selected.add(hit.id);
                                    } else {
                                      _selected.remove(hit.id);
                                    }
                                  }),
                          )
                        : null,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MediaViewerPage(
                          assets: [
                            widget.asset,
                            ...hits.map((hit) => hit.asset),
                          ],
                          initialIndex: index + 1,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_selected.isNotEmpty)
          FilledButton.icon(
            onPressed: busy ? null : _bundle,
            icon: const Icon(Icons.collections_outlined),
            label: Text('捆绑所选 ${_selected.length} 项'),
          ),
      ],
    );
  }
}
