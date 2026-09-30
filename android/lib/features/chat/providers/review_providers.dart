import 'dart:async';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/storage/hive_service.dart';
import 'package:torrid/features/chat/models/review_models.dart';
import 'package:torrid/features/chat/providers/chat_providers.dart';
import 'package:torrid/features/chat/services/review_api_service.dart';

part 'review_providers.g.dart';

/// 预设列表状态。
class ReviewPresetsState {
  /// 已按名称排序的预设（含本地镜像里读到的那份）。
  final List<ReviewPreset> presets;

  /// 正在与服务端同步。
  final bool syncing;

  /// 同步失败提示：列表仍可用（本地镜像），只是可能与服务端不一致。
  final String? error;

  const ReviewPresetsState({
    this.presets = const [],
    this.syncing = false,
    this.error,
  });

  ReviewPresetsState copyWith({
    List<ReviewPreset>? presets,
    bool? syncing,
    String? error,
    bool clearError = false,
  }) {
    return ReviewPresetsState(
      presets: presets ?? this.presets,
      syncing: syncing ?? this.syncing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 语气/角色预设：服务端权威 + 本地 Hive 镜像。
///
/// 读：先用镜像（离线可用），再异步与服务端对齐；
/// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。
@Riverpod(keepAlive: true)
class ReviewPresetsController extends _$ReviewPresetsController {
  @override
  ReviewPresetsState build() {
    final cached = _sorted(_box.values.toList());
    Future.microtask(refresh);
    return ReviewPresetsState(presets: cached);
  }

  Box<ReviewPreset> get _box =>
      Hive.box<ReviewPreset>(HiveService.reviewPresetBoxName);

  /// 从服务端拉取并覆盖本地镜像；失败时保留镜像并如实提示。
  Future<void> refresh() async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final presets = await ref.read(reviewApiProvider).fetchPresets();
      await _replaceCache(presets);
      state = ReviewPresetsState(presets: _sorted(presets));
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
    }
  }

  /// 整体保存；返回是否成功（失败时本地与服务端都保持原样）。
  Future<bool> save(List<ReviewPreset> presets) async {
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final saved = await ref.read(reviewApiProvider).savePresets(presets);
      await _replaceCache(saved);
      state = ReviewPresetsState(presets: _sorted(saved));
      return true;
    } catch (e) {
      state = state.copyWith(syncing: false, error: e.toString());
      return false;
    }
  }

  Future<void> _replaceCache(List<ReviewPreset> presets) async {
    await _box.clear();
    for (final preset in presets) {
      await _box.put(preset.id, preset);
    }
  }

  /// 排序只为了展示稳定：镜像的读取顺序由 Hive 决定，不能反过来影响推送顺序。
  List<ReviewPreset> _sorted(List<ReviewPreset> items) =>
      [...items]..sort((a, b) => a.name.compareTo(b.name));
}

/// 本地回顾历史（只存本机，不回传服务端）。
@Riverpod(keepAlive: true)
class ReviewHistoryController extends _$ReviewHistoryController {
  @override
  List<ReviewRecord> build() => _sorted(_box.values.toList());

  Box<ReviewRecord> get _box =>
      Hive.box<ReviewRecord>(HiveService.reviewHistoryBoxName);

  Future<void> add(ReviewRecord record) async {
    await _box.put(record.id, record);
    state = _sorted([...state, record]);
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
    state = [
      for (final item in state)
        if (item.id != id) item,
    ];
  }

  Future<void> clear() async {
    await _box.clear();
    state = const [];
  }

  List<ReviewRecord> _sorted(List<ReviewRecord> items) =>
      items..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// 一次生成过程中的草稿状态（历史上限之外的内容不落库，只在本状态里）。
class ReviewDraftState {
  final String content;

  /// 服务端下发的"本次依据"确定性统计。
  final String stats;

  final bool streaming;
  final String? error;

  /// 一次性提示（如模型被抢占），展示后由页面清除。
  final String? notice;

  const ReviewDraftState({
    this.content = '',
    this.stats = '',
    this.streaming = false,
    this.error,
    this.notice,
  });

  bool get isEmpty => content.trim().isEmpty && stats.trim().isEmpty;

  ReviewDraftState copyWith({
    String? content,
    String? stats,
    bool? streaming,
    String? error,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return ReviewDraftState(
      content: content ?? this.content,
      stats: stats ?? this.stats,
      streaming: streaming ?? this.streaming,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// 回顾生成控制器。
@Riverpod(keepAlive: true)
class ReviewDraftController extends _$ReviewDraftController {
  CancelToken? _cancelToken;

  @override
  ReviewDraftState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const ReviewDraftState();
  }

  /// 生成一次回顾；内容随流式增量更新，成功后才写入本地历史。
  Future<void> generate({
    required ReviewPreset preset,
    required ReviewScope scope,
    String focus = '',
  }) async {
    if (state.streaming) return;

    final options = ref.read(chatOptionsControllerProvider);
    final today = DateTime.now();
    final span = scope.resolve(today);
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;

    final buffer = StringBuffer();
    var stats = '';
    state = const ReviewDraftState(streaming: true);

    try {
      final stream = ref.read(reviewApiProvider).generate(
        request: {
          ...scope.toRequestFields(today),
          'role': preset.role,
          'tone': preset.tone,
          if (focus.trim().isNotEmpty) 'focus': focus.trim(),
          if (options.model.isNotEmpty) 'model': options.model,
          if (options.numCtx > 0) 'num_ctx': options.numCtx,
          // 回顾是一次性写作任务：思考链只是拖慢首字，端上也不展示
          'think': false,
          'temperature': options.temperature,
          'keep_alive_seconds': options.customKeepAlive
              ? options.keepAliveSeconds
              : null,
        },
        cancelToken: cancelToken,
      );

      await for (final event in stream) {
        switch (event.type) {
          case 'stats':
            stats = event.content;
            state = state.copyWith(stats: stats);
          case 'delta':
            buffer.write(event.content);
            state = state.copyWith(content: buffer.toString());
          case 'notice':
            state = state.copyWith(notice: event.content);
          case 'aborted':
            // 被另一个模型抢占：不是错误，可直接重新生成
            state = state.copyWith(streaming: false, notice: event.error);
            return;
          case 'error':
            throw AiStreamException(event.error ?? '模型返回错误');
          default:
            break;
        }
      }

      final content = buffer.toString().trim();
      if (content.isEmpty) {
        state = state.copyWith(streaming: false, error: '模型没有返回内容');
        return;
      }
      state = state.copyWith(content: content, streaming: false);
      await ref.read(reviewHistoryControllerProvider.notifier).add(
            ReviewRecord.create(
              presetName: preset.name,
              span: '${span.from} ~ ${span.to}',
              content: content,
              stats: stats,
            ),
          );
    } catch (e) {
      final cancelled = e is DioException && e.type == DioExceptionType.cancel;
      state = state.copyWith(
        streaming: false,
        error: cancelled ? null : e.toString(),
      );
    } finally {
      _cancelToken = null;
    }
  }

  /// 中断当前生成。
  void stop() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void clearNotice() => state = state.copyWith(clearNotice: true);

  /// 把一条历史回顾载入当前视图。
  void show(ReviewRecord record) {
    state = ReviewDraftState(content: record.content, stats: record.stats);
  }
}
