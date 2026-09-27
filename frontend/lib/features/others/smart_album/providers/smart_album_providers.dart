import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/others/ai/models/ai_search_models.dart';
import 'package:torrid/features/others/ai/services/ai_api_service.dart';

part 'smart_album_providers.g.dart';

/// 智能相册页的业务状态。
///
/// 检索结果与人物分组都放在这里，页面只做渲染与输入；
/// [loading] 为检索与人物分组共用（与页面单一的进度指示器一致）。
class SmartAlbumState {
  /// 当前检索方式。
  final AiSearchMode mode;

  /// 是否有请求在途。
  final bool loading;

  /// 最近一次失败信息（页面按原样展示）。
  final String? error;

  /// 最近一次检索结果。
  final AiSearchResult result;

  /// 人物分组；null 表示尚未加载。
  final List<AiPerson>? persons;

  const SmartAlbumState({
    this.mode = AiSearchMode.auto,
    this.loading = false,
    this.error,
    this.result = AiSearchResult.empty,
    this.persons,
  });

  SmartAlbumState copyWith({
    AiSearchMode? mode,
    bool? loading,
    String? error,
    bool clearError = false,
    AiSearchResult? result,
    List<AiPerson>? persons,
  }) {
    return SmartAlbumState(
      mode: mode ?? this.mode,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      result: result ?? this.result,
      persons: persons ?? this.persons,
    );
  }
}

/// 智能相册页控制器：检索、以图搜图、人物分组与 AI 分析结果的取数逻辑。
///
/// 只消费服务端 AI 能力，不写本地缓存；随页面存活（离开页面即重置，
/// 与页面自身持有状态时的行为一致）。需要跨次进入保留结果时改为 keepAlive。
@riverpod
class SmartAlbumController extends _$SmartAlbumController {
  @override
  SmartAlbumState build() => const SmartAlbumState();

  /// 文本检索。
  Future<void> search(String query) async {
    final text = query.trim();
    final mode = state.mode;
    // 纯条件检索（文件名模式必须给词）没有查询词时不做请求
    if (text.isEmpty && mode == AiSearchMode.filename) return;

    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await ref.read(aiApiProvider).search(text, mode: mode);
      state = state.copyWith(result: result);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 切换检索方式；旧结果不再对应故清空，已有查询词则立即重检索。
  Future<void> setMode(AiSearchMode mode, String query) async {
    state = state.copyWith(mode: mode, result: AiSearchResult.empty);
    if (query.trim().isNotEmpty) await search(query);
  }

  /// 清空检索结果（输入框的清除按钮）。
  void clearResult() => state = state.copyWith(result: AiSearchResult.empty);

  /// 以图搜图；成功返回结果，失败写入错误并返回 null。
  Future<AiSearchResult?> searchSimilar(String mediaId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await ref.read(aiApiProvider).similar(mediaId);
      state = state.copyWith(result: result);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 人物分组（首次切到"人物"页时调用）。
  Future<void> loadPersons() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final persons = await ref.read(aiApiProvider).fetchPersons();
      state = state.copyWith(persons: persons);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 按人物检索其全部媒体；成功返回结果，失败写入错误并返回 null。
  Future<AiSearchResult?> searchByPerson(AiPerson person) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await ref.read(aiApiProvider).searchByPerson(person.id);
      state = state.copyWith(result: result);
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  /// 读取单个媒体的 AI 分析结果（失败抛错，由调用方展示）。
  Future<AiMediaDetail> fetchMediaDetail(String mediaId) =>
      ref.read(aiApiProvider).fetchMediaDetail(mediaId);
}
