import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';

part 'smart_album_providers.g.dart';

/// 智能相册的检索状态。
///
/// 页面只负责渲染与导航；检索方式、在途请求、错误与结果都在这里，
/// 避免把请求编排塞进 `State`（同一套写法见 immich 的 providers）。
class SmartAlbumState {
  final AiSearchMode mode;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool personsLoading;
  final String? error;
  final AiSearchResult result;

  /// 人物分组；null 表示尚未加载过（首次切到"人物"页才请求）。
  final List<AiPerson>? persons;

  /// 需要回填到输入框的文本（以图搜图、点人物进入检索时）。
  final String queryText;

  /// 自增版本号：只要它变了，页面就把 [queryText] 写回输入框一次。
  /// 仅比较文本会漏掉"文本相同但要重新回填"的情况（例如连着两次以图搜图）。
  final int queryRevision;

  const SmartAlbumState({
    this.mode = AiSearchMode.auto,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.personsLoading = false,
    this.error,
    this.result = AiSearchResult.empty,
    this.persons,
    this.queryText = '',
    this.queryRevision = 0,
  });

  SmartAlbumState copyWith({
    AiSearchMode? mode,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? personsLoading,
    String? error,
    AiSearchResult? result,
    List<AiPerson>? persons,
    String? queryText,
    int? queryRevision,
    bool clearError = false,
  }) {
    return SmartAlbumState(
      mode: mode ?? this.mode,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      personsLoading: personsLoading ?? this.personsLoading,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
      persons: persons ?? this.persons,
      queryText: queryText ?? this.queryText,
      queryRevision: queryRevision ?? this.queryRevision,
    );
  }
}

@riverpod
class SmartAlbumController extends _$SmartAlbumController {
  int _requestId = 0;
  int _personsRequestId = 0;
  int _nextOffset = 0;
  Future<AiSearchResult> Function(int offset)? _loadPage;

  @override
  SmartAlbumState build() {
    ref.onDispose(() {
      _requestId++;
      _personsRequestId++;
    });
    return const SmartAlbumState();
  }

  /// 切换检索方式；旧结果不再对应，直接清掉避免误读。
  void setMode(AiSearchMode mode) {
    if (mode == state.mode) return;
    clearResult();
    state = state.copyWith(mode: mode);
  }

  /// 文本检索。文件名模式没有查询词时不做请求（纯条件检索无从匹配）。
  Future<void> search(String query) {
    final text = query.trim();
    if (text.isEmpty && state.mode == AiSearchMode.filename) {
      return Future.value();
    }
    final api = ref.read(aiApiProvider);
    final mode = state.mode;
    return _run((offset) => api.search(text, mode: mode, offset: offset));
  }

  /// 以图搜图。
  Future<void> searchSimilar(String mediaId) {
    final api = ref.read(aiApiProvider);
    return _run(
      (offset) => api.similar(mediaId, offset: offset),
      queryText: '与所选图片相似',
    );
  }

  /// 按人物筛选其全部媒体。
  Future<void> searchByPerson(AiPerson person) {
    final api = ref.read(aiApiProvider);
    return _run(
      (offset) => api.searchByPerson(person.id, offset: offset),
      queryText: person.displayName,
    );
  }

  /// 加载人物分组（首次切到"人物"页时调用）。
  Future<void> loadPersons() async {
    if (state.personsLoading) return;
    final requestId = ++_personsRequestId;
    state = state.copyWith(personsLoading: true, clearError: true);
    try {
      final persons = await ref.read(aiApiProvider).fetchPersons();
      if (requestId != _personsRequestId) return;
      state = state.copyWith(persons: persons, personsLoading: false);
    } catch (e) {
      if (requestId != _personsRequestId) return;
      state = state.copyWith(personsLoading: false, error: aiFriendlyError(e));
    }
  }

  /// 清空当前结果（清空输入框时）。
  void clearResult() {
    _requestId++;
    _loadPage = null;
    _nextOffset = 0;
    state = state.copyWith(
      result: AiSearchResult.empty,
      loading: false,
      loadingMore: false,
      hasMore: false,
      clearError: true,
    );
  }

  Future<void> _run(
    Future<AiSearchResult> Function(int offset) action, {
    String? queryText,
  }) async {
    clearResult();
    _loadPage = action;
    state = state.copyWith(
      queryText: queryText,
      queryRevision: queryText == null ? null : state.queryRevision + 1,
    );
    await _fetchPage(append: false);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    await _fetchPage(append: true);
  }

  Future<void> _fetchPage({required bool append}) async {
    final action = _loadPage;
    if (action == null) return;
    final requestId = _requestId;
    state = state.copyWith(
      loading: !append,
      loadingMore: append,
      clearError: true,
    );
    try {
      final page = await action(_nextOffset);
      if (requestId != _requestId) return;
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
    } catch (e) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: aiFriendlyError(e),
      );
    }
  }
}
