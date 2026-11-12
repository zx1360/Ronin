// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'immich_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 筛选条件 Provider

@ProviderFor(ImmichFilterNotifier)
final immichFilterProvider = ImmichFilterNotifierProvider._();

/// 筛选条件 Provider
final class ImmichFilterNotifierProvider
    extends $NotifierProvider<ImmichFilterNotifier, ImmichFilter> {
  /// 筛选条件 Provider
  ImmichFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immichFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immichFilterNotifierHash();

  @$internal
  @override
  ImmichFilterNotifier create() => ImmichFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImmichFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImmichFilter>(value),
    );
  }
}

String _$immichFilterNotifierHash() =>
    r'1a9257ee9a67ab9c8a02d8206638c4abced59ca8';

/// 筛选条件 Provider

abstract class _$ImmichFilterNotifier extends $Notifier<ImmichFilter> {
  ImmichFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ImmichFilter, ImmichFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImmichFilter, ImmichFilter>,
              ImmichFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）

@ProviderFor(ImmichMedia)
final immichMediaProvider = ImmichMediaProvider._();

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
final class ImmichMediaProvider
    extends $AsyncNotifierProvider<ImmichMedia, ImmichMediaPage> {
  /// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
  ImmichMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immichMediaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immichMediaHash();

  @$internal
  @override
  ImmichMedia create() => ImmichMedia();
}

String _$immichMediaHash() => r'cdd7e82760c4215e745258cc6ce9e68d1a133416';

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）

abstract class _$ImmichMedia extends $AsyncNotifier<ImmichMediaPage> {
  FutureOr<ImmichMediaPage> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ImmichMediaPage>, ImmichMediaPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ImmichMediaPage>, ImmichMediaPage>,
              AsyncValue<ImmichMediaPage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 选中集合

@ProviderFor(ImmichSelection)
final immichSelectionProvider = ImmichSelectionProvider._();

/// 选中集合
final class ImmichSelectionProvider
    extends $NotifierProvider<ImmichSelection, Set<String>> {
  /// 选中集合
  ImmichSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immichSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immichSelectionHash();

  @$internal
  @override
  ImmichSelection create() => ImmichSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$immichSelectionHash() => r'a0cb5bd73351e136a4e2dd2fc1a93db1f8a4a670';

/// 选中集合

abstract class _$ImmichSelection extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ImmichEdits)
final immichEditsProvider = ImmichEditsProvider._();

final class ImmichEditsProvider
    extends
        $NotifierProvider<
          ImmichEdits,
          ({ImmichMediaUpdate? media, int tagRevision})
        > {
  ImmichEditsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immichEditsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immichEditsHash();

  @$internal
  @override
  ImmichEdits create() => ImmichEdits();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({ImmichMediaUpdate? media, int tagRevision}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({ImmichMediaUpdate? media, int tagRevision})>(
            value,
          ),
    );
  }
}

String _$immichEditsHash() => r'904719223834f435ad569aae72efd6e3304a33d2';

abstract class _$ImmichEdits
    extends $Notifier<({ImmichMediaUpdate? media, int tagRevision})> {
  ({ImmichMediaUpdate? media, int tagRevision}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({ImmichMediaUpdate? media, int tagRevision}),
              ({ImmichMediaUpdate? media, int tagRevision})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({ImmichMediaUpdate? media, int tagRevision}),
                ({ImmichMediaUpdate? media, int tagRevision})
              >,
              ({ImmichMediaUpdate? media, int tagRevision}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）

@ProviderFor(ImmichActions)
final immichActionsProvider = ImmichActionsProvider._();

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
final class ImmichActionsProvider
    extends $NotifierProvider<ImmichActions, bool> {
  /// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
  ImmichActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'immichActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$immichActionsHash();

  @$internal
  @override
  ImmichActions create() => ImmichActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$immichActionsHash() => r'0d57e16ebc1b0c0293650835df08b2af82c0fbc1';

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）

abstract class _$ImmichActions extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
