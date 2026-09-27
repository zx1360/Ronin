/// "近期回顾"面板的状态与动作。
///
/// 刻意保持 `keepAlive`：生成本地叙述可能要好几分钟，用户关掉面板去聊天也不该
/// 让请求被丢掉 —— 结果留在这里，重新打开面板即可看到。
library;

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/api/generated/api_contract.dart';
import 'package:torrid/features/review/services/review_api_service.dart';

part 'review_providers.g.dart';

/// 回顾面板状态。
class ReviewState {
  const ReviewState({
    this.days = defaultReviewDays,
    this.presetId,
    this.presets = const [],
    this.loadingPresets = false,
    this.presetError,
    this.generating = false,
    this.result,
    this.error,
    this.notice,
  });

  /// 回顾窗口（天），1 ~ [maxReviewDays]。
  final int days;

  /// 选中的预设；null 表示交给服务端用默认预设。
  final String? presetId;

  final List<ReviewPreset> presets;
  final bool loadingPresets;

  /// 读取预设失败的原因（与"生成失败"分开，重试动作不同）。
  final String? presetError;

  /// 正在等待服务端生成（本地模型推理中）。
  final bool generating;

  final ReviewResult? result;

  /// 生成失败的原因（面板内展示，可重试）。
  final String? error;

  /// 一次性提示（预设保存/删除反馈），展示后清除。
  final String? notice;

  /// 当前选中的预设对象（null = 服务端默认预设）。
  ReviewPreset? get selectedPreset {
    if (presetId != null) {
      for (final preset in presets) {
        if (preset.id == presetId) return preset;
      }
    }
    for (final preset in presets) {
      if (preset.isDefault) return preset;
    }
    return null;
  }

  bool get hasPresets => presets.isNotEmpty;

  ReviewState copyWith({
    int? days,
    String? presetId,
    bool clearPresetId = false,
    List<ReviewPreset>? presets,
    bool? loadingPresets,
    String? presetError,
    bool clearPresetError = false,
    bool? generating,
    ReviewResult? result,
    bool clearResult = false,
    String? error,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) {
    return ReviewState(
      days: days ?? this.days,
      presetId: clearPresetId ? null : (presetId ?? this.presetId),
      presets: presets ?? this.presets,
      loadingPresets: loadingPresets ?? this.loadingPresets,
      presetError:
          clearPresetError ? null : (presetError ?? this.presetError),
      generating: generating ?? this.generating,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

@Riverpod(keepAlive: true)
class ReviewController extends _$ReviewController {
  CancelToken? _cancelToken;

  @override
  ReviewState build() {
    ref.onDispose(() => _cancelToken?.cancel());
    return const ReviewState();
  }

  /// 拉取预设（已拉到就跳过；[force] 用于失败后重试）。
  Future<void> loadPresets({bool force = false}) async {
    if (state.loadingPresets) return;
    if (!force && state.presets.isNotEmpty) return;

    state = state.copyWith(
      loadingPresets: true,
      clearPresetError: true,
    );
    try {
      final presets = await ref.read(reviewApiProvider).listPresets();
      state = state.copyWith(loadingPresets: false, presets: presets);
    } catch (e) {
      state = state.copyWith(loadingPresets: false, presetError: e.toString());
    }
  }

  /// 切换回顾窗口；参数变了就丢掉旧结果（旧叙述对应的不是这个周期）。
  void selectDays(int days) {
    final clamped = days.clamp(minReviewDays, maxReviewDays);
    if (clamped == state.days) return;
    state = state.copyWith(days: clamped, clearResult: true, clearError: true);
  }

  /// 切换预设；同样丢掉旧结果（旧叙述用的是另一个语气/角色）。
  void selectPreset(String? presetId) {
    if (presetId == state.presetId) return;
    state = state.copyWith(
      presetId: presetId,
      clearPresetId: presetId == null,
      clearResult: true,
      clearError: true,
    );
  }

  /// 生成回顾；[force] 为真时让服务端忽略缓存重新推理。
  Future<void> generate({bool force = false}) async {
    if (state.generating) return;

    final token = CancelToken();
    _cancelToken = token;
    state = state.copyWith(
      generating: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref.read(reviewApiProvider).generate(
            days: state.days,
            presetId: state.presetId,
            force: force,
            cancelToken: token,
          );
      state = state.copyWith(generating: false, result: result);
    } catch (e) {
      state = state.copyWith(generating: false, error: e.toString());
    } finally {
      _cancelToken = null;
    }
  }

  /// 保存（新建或更新）预设。成功返回 null，失败返回可读原因。
  Future<String?> savePreset({
    String? id,
    required String name,
    required String tone,
    required String role,
    required bool isDefault,
  }) async {
    try {
      final presets = await ref.read(reviewApiProvider).upsertPreset(
            id: id,
            name: name,
            tone: tone,
            role: role,
            isDefault: isDefault,
          );
      state = state.copyWith(presets: presets, notice: '预设已保存');
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 删除预设（默认预设不可删除）。成功返回 null，失败返回可读原因。
  Future<String?> deletePreset(String id) async {
    try {
      final presets = await ref.read(reviewApiProvider).deletePreset(id);
      // 删掉的正好是当前选中项时，回落到服务端默认预设
      final stillExists = presets.any((preset) => preset.id == state.presetId);
      state = state.copyWith(
        presets: presets,
        clearPresetId: !stillExists,
        clearResult: !stillExists,
        notice: '预设已删除',
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 清除一次性提示（面板展示后调用）。
  void dismissNotice() => state = state.copyWith(clearNotice: true);
}
