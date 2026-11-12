// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 语气/角色预设：服务端权威 + 本地镜像。
///
/// 读：先用镜像（离线可用），再异步与服务端对齐；
/// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。

@ProviderFor(ReviewPresetsController)
final reviewPresetsControllerProvider = ReviewPresetsControllerProvider._();

/// 语气/角色预设：服务端权威 + 本地镜像。
///
/// 读：先用镜像（离线可用），再异步与服务端对齐；
/// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。
final class ReviewPresetsControllerProvider
    extends $NotifierProvider<ReviewPresetsController, ReviewPresetsState> {
  /// 语气/角色预设：服务端权威 + 本地镜像。
  ///
  /// 读：先用镜像（离线可用），再异步与服务端对齐；
  /// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。
  ReviewPresetsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewPresetsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewPresetsControllerHash();

  @$internal
  @override
  ReviewPresetsController create() => ReviewPresetsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewPresetsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewPresetsState>(value),
    );
  }
}

String _$reviewPresetsControllerHash() =>
    r'a6640ddff20968c17ed517bdb5a4a6704effcd6f';

/// 语气/角色预设：服务端权威 + 本地镜像。
///
/// 读：先用镜像（离线可用），再异步与服务端对齐；
/// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。

abstract class _$ReviewPresetsController extends $Notifier<ReviewPresetsState> {
  ReviewPresetsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReviewPresetsState, ReviewPresetsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReviewPresetsState, ReviewPresetsState>,
              ReviewPresetsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 回顾生成控制器。

@ProviderFor(ReviewDraftController)
final reviewDraftControllerProvider = ReviewDraftControllerProvider._();

/// 回顾生成控制器。
final class ReviewDraftControllerProvider
    extends $NotifierProvider<ReviewDraftController, ReviewDraftState> {
  /// 回顾生成控制器。
  ReviewDraftControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reviewDraftControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reviewDraftControllerHash();

  @$internal
  @override
  ReviewDraftController create() => ReviewDraftController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReviewDraftState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReviewDraftState>(value),
    );
  }
}

String _$reviewDraftControllerHash() =>
    r'305994e6fe1356e6e56925f39c8c6fd2e860e529';

/// 回顾生成控制器。

abstract class _$ReviewDraftController extends $Notifier<ReviewDraftState> {
  ReviewDraftState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReviewDraftState, ReviewDraftState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReviewDraftState, ReviewDraftState>,
              ReviewDraftState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
