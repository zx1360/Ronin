import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';

part 'smart_album_providers.g.dart';

final albumPeopleProvider = FutureProvider.autoDispose<List<AiPerson>>(
  (ref) => ref.watch(aiApiProvider).fetchPersons(),
);

class SmartAlbumState {
  final AiSearchMode mode;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool timeline;
  final bool includeDeleted;
  final String? error;
  final AiSearchResult result;
  final String queryText;
  final String subject;
  final int revision;

  const SmartAlbumState({
    this.mode = AiSearchMode.auto,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.timeline = false,
    this.includeDeleted = false,
    this.error,
    this.result = AiSearchResult.empty,
    this.queryText = '',
    this.subject = '',
    this.revision = 0,
  });

  SmartAlbumState copyWith({
    AiSearchMode? mode,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? timeline,
    bool? includeDeleted,
    String? error,
    bool clearError = false,
    AiSearchResult? result,
    String? queryText,
    String? subject,
    int? revision,
  }) => SmartAlbumState(
    mode: mode ?? this.mode,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    timeline: timeline ?? this.timeline,
    includeDeleted: includeDeleted ?? this.includeDeleted,
    error: clearError ? null : error ?? this.error,
    result: result ?? this.result,
    queryText: queryText ?? this.queryText,
    subject: subject ?? this.subject,
    revision: revision ?? this.revision,
  );
}

typedef _AlbumQuery = ({
  String text,
  String subject,
  String? mediaId,
  String? personId,
});

@riverpod
class SmartAlbumController extends _$SmartAlbumController {
  int _requestId = 0;
  int _nextOffset = 0;
  _AlbumQuery? _query;

  @override
  SmartAlbumState build() {
    ref.watch(aiApiProvider);
    ref.listen(immichMediaUpdateProvider, (_, update) {
      if (update == null || _query == null) return;
      if (update.changesVisibility || state.loading || state.loadingMore) {
        unawaited(reload());
      } else {
        _updateAssets(update.assets);
      }
    });
    ref.onDispose(() {
      _requestId++;
      _query = null;
    });
    return const SmartAlbumState();
  }

  void _updateAssets(List<MediaAsset> assets) {
    final byId = {for (final asset in assets) asset.id: asset};
    final result = state.result;
    state = state.copyWith(
      result: AiSearchResult(
        mode: result.mode,
        total: result.total,
        hits: [
          for (final hit in result.hits)
            if (byId[hit.id] case final asset?)
              AiSearchHit(asset: asset, score: hit.score, sources: hit.sources)
            else
              hit,
        ],
      ),
    );
  }

  Future<void> search(String text, {AiSearchMode? mode}) {
    final query = text.trim();
    _query = query.isEmpty
        ? null
        : (text: query, subject: '', mediaId: null, personId: null);
    return _restart(mode: mode);
  }

  Future<void> searchSimilar(MediaAsset asset) {
    final name = asset.filePath.split(RegExp(r'[/\\]')).last;
    _query = (
      text: '',
      subject: '相似图 · $name',
      mediaId: asset.id,
      personId: null,
    );
    return reload();
  }

  Future<void> searchByPerson(AiPerson person) {
    _query = (
      text: '',
      subject: '人物 · ${person.displayName}',
      mediaId: null,
      personId: person.id,
    );
    return reload();
  }

  void clearResult() {
    _query = null;
    unawaited(reload());
  }

  Future<void> setTimeline(bool value) => _restart(timeline: value);

  Future<void> setIncludeDeleted(bool value) => _restart(includeDeleted: value);

  Future<void> reload() => _restart();

  Future<void> _restart({
    AiSearchMode? mode,
    bool? timeline,
    bool? includeDeleted,
  }) async {
    _requestId++;
    _nextOffset = 0;
    state = state.copyWith(
      mode: mode,
      timeline: timeline,
      includeDeleted: includeDeleted,
      queryText: _query?.text ?? '',
      subject: _query?.subject ?? '',
      result: AiSearchResult.empty,
      revision: state.revision + 1,
      loading: _query != null,
      loadingMore: false,
      hasMore: false,
      clearError: true,
    );
    await _fetchPage(append: false);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    await _fetchPage(append: true);
  }

  Future<void> _fetchPage({required bool append}) async {
    final query = _query;
    if (query == null) return;
    final requestId = _requestId;
    final mode =
        query.personId != null ||
            (append &&
                state.mode == AiSearchMode.auto &&
                state.result.mode == 'keyword')
        ? AiSearchMode.keyword
        : state.mode;
    state = state.copyWith(loadingMore: append, clearError: true);
    try {
      final page = await ref
          .read(aiApiProvider)
          .search(
            query.text,
            mode: mode,
            mediaId: query.mediaId,
            personId: query.personId,
            timeline: state.timeline,
            includeDeleted: state.includeDeleted,
            offset: _nextOffset,
          );
      if (requestId != _requestId) return;
      if (append && page.mode != state.result.mode) {
        await reload();
        return;
      }
      _nextOffset += page.hits.length;
      final byId = {
        if (append)
          for (final hit in state.result.hits) hit.id: hit,
        for (final hit in page.hits) hit.id: hit,
      };
      state = state.copyWith(
        result: AiSearchResult(
          hits: byId.values.toList(),
          total: page.total,
          mode: page.mode,
        ),
        loading: false,
        loadingMore: false,
        hasMore: page.hits.isNotEmpty && _nextOffset < page.total,
      );
    } catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: aiFriendlyError(error),
      );
    }
  }
}
