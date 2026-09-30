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
    this.error,
    this.result = AiSearchResult.empty,
    this.persons,
    this.queryText = '',
    this.queryRevision = 0,
  });

  SmartAlbumState copyWith({
    AiSearchMode? mode,
    bool? loading,
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
  @override
  SmartAlbumState build() => const SmartAlbumState();

  /// 切换检索方式；旧结果不再对应，直接清掉避免误读。
  void setMode(AiSearchMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(
      mode: mode,
      result: AiSearchResult.empty,
      clearError: true,
    );
  }

  /// 文本检索。文件名模式没有查询词时不做请求（纯条件检索无从匹配）。
  Future<void> search(String query) {
    final text = query.trim();
    if (text.isEmpty && state.mode == AiSearchMode.filename) {
      return Future.value();
    }
    return _run(() => ref.read(aiApiProvider).search(text, mode: state.mode));
  }

  /// 以图搜图。
  Future<void> searchSimilar(String mediaId) => _run(
        () => ref.read(aiApiProvider).similar(mediaId),
        queryText: '与所选图片相似',
      );

  /// 按人物筛选其全部媒体。
  Future<void> searchByPerson(AiPerson person) => _run(
        () => ref.read(aiApiProvider).searchByPerson(person.id),
        queryText: person.displayName,
      );

  /// 加载人物分组（首次切到"人物"页时调用）。
  Future<void> loadPersons() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final persons = await ref.read(aiApiProvider).fetchPersons();
      state = state.copyWith(persons: persons, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: aiFriendlyError(e));
    }
  }

  /// 清空当前结果（清空输入框时）。
  void clearResult() {
    state = state.copyWith(result: AiSearchResult.empty, clearError: true);
  }

  Future<void> _run(
    Future<AiSearchResult> Function() action, {
    String? queryText,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await action();
      state = state.copyWith(
        result: result,
        loading: false,
        queryText: queryText,
        queryRevision:
            queryText == null ? null : state.queryRevision + 1,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: aiFriendlyError(e));
    }
  }
}
