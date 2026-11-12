import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart' show FutureProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/immich/providers/immich_providers.dart';

part 'smart_album_providers.g.dart';

final albumPeopleProvider = FutureProvider.autoDispose<List<AiPerson>>(
  (ref) => ref.watch(aiApiProvider).fetchPersons(),
);

class AlbumSearchFilters {
  final DateTimeRange? dates;
  final String mimeType;
  final Set<String> tagIds;

  const AlbumSearchFilters({
    this.dates,
    this.mimeType = '',
    this.tagIds = const {},
  });

  int get count =>
      (dates == null ? 0 : 1) +
      (mimeType.isEmpty ? 0 : 1) +
      (tagIds.isEmpty ? 0 : 1);
}

class SmartAlbumState {
  final AiSearchMode mode;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool timeline;
  final bool includeDeleted;
  final AlbumSearchFilters filters;
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
    this.filters = const AlbumSearchFilters(),
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
    AlbumSearchFilters? filters,
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
    filters: filters ?? this.filters,
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
  CancelToken? _request;
  int _nextOffset = 0;
  _AlbumQuery? _query;

  @override
  SmartAlbumState build() {
    ref.watch(aiApiProvider);
    ref.listen(immichMediaUpdateProvider, (_, update) {
      if (update == null || (_query == null && state.filters.count == 0)) return;
      if ((update.changesVisibility && !state.includeDeleted) ||
          state.loading ||
          state.loadingMore) {
        unawaited(reload());
      } else {
        _updateAssets(update.assets);
      }
    });
    ref.listen(immichTagRevisionProvider, (_, __) {
      if (state.filters.tagIds.isNotEmpty) unawaited(reload());
    });
    ref.onDispose(() {
      _request?.cancel();
      _request = null;
      _query = null;
    });
    return const SmartAlbumState();
  }

  void _updateAssets(List<MediaAsset> assets) {
    final byId = {for (final asset in assets) asset.id: asset};
    final result = state.result;
    if (!result.hits.any((hit) => byId.containsKey(hit.id))) return;
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

  Future<void> search(
    String text, {
    AiSearchMode? mode,
    AlbumSearchFilters? filters,
  }) {
    final query = text.trim();
    _query = query.isEmpty
        ? null
        : (text: query, subject: '', mediaId: null, personId: null);
    return _restart(mode: mode, filters: filters);
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
    unawaited(_restart(filters: const AlbumSearchFilters()));
  }

  Future<void> setTimeline(bool value) => _restart(timeline: value);

  Future<void> setIncludeDeleted(bool value) => _restart(includeDeleted: value);

  Future<void> setFilters(AlbumSearchFilters filters) =>
      _restart(filters: filters);

  Future<void> reload() => _restart();

  Future<void> _restart({
    AiSearchMode? mode,
    bool? timeline,
    bool? includeDeleted,
    AlbumSearchFilters? filters,
  }) async {
    _request?.cancel();
    _request = null;
    _nextOffset = 0;
    final nextFilters = filters ?? state.filters;
    state = state.copyWith(
      mode: mode,
      timeline: timeline,
      includeDeleted: includeDeleted,
      filters: nextFilters,
      queryText: _query?.text ?? '',
      subject: _query?.subject ?? '',
      result: AiSearchResult.empty,
      revision: state.revision + 1,
      loading: _query != null || nextFilters.count > 0,
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
    final filters = state.filters;
    if (query == null && filters.count == 0) return;
    final token = _request = CancelToken();
    final mode =
        query == null ||
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
            query?.text ?? '',
            mode: mode,
            mediaId: query?.mediaId,
            personId: query?.personId,
            timeline: state.timeline,
            includeDeleted: state.includeDeleted,
            tagIds: filters.tagIds,
            mimeType: filters.mimeType,
            from: filters.dates?.start,
            to: filters.dates?.end,
            offset: _nextOffset,
            cancelToken: token,
          );
      if (token.isCancelled) return;
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
      if (token.isCancelled) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: aiFriendlyError(error),
      );
    } finally {
      if (identical(_request, token)) _request = null;
    }
  }
}
