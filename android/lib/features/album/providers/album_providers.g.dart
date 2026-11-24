// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 筛选条件 Provider

@ProviderFor(AlbumFilterNotifier)
final albumFilterProvider = AlbumFilterNotifierProvider._();

/// 筛选条件 Provider
final class AlbumFilterNotifierProvider
    extends $NotifierProvider<AlbumFilterNotifier, AlbumFilter> {
  /// 筛选条件 Provider
  AlbumFilterNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumFilterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumFilterNotifierHash();

  @$internal
  @override
  AlbumFilterNotifier create() => AlbumFilterNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlbumFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlbumFilter>(value),
    );
  }
}

String _$albumFilterNotifierHash() =>
    r'3ded870b444670dca7320f61fd101933580d782e';

/// 筛选条件 Provider

abstract class _$AlbumFilterNotifier extends $Notifier<AlbumFilter> {
  AlbumFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AlbumFilter, AlbumFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AlbumFilter, AlbumFilter>,
              AlbumFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）

@ProviderFor(AlbumMedia)
final albumMediaProvider = AlbumMediaProvider._();

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
final class AlbumMediaProvider
    extends $AsyncNotifierProvider<AlbumMedia, AlbumMediaPage> {
  /// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
  AlbumMediaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumMediaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumMediaHash();

  @$internal
  @override
  AlbumMedia create() => AlbumMedia();
}

String _$albumMediaHash() => r'7a077cbacb057ae83733d5caa7da4d359ef0e98d';

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）

abstract class _$AlbumMedia extends $AsyncNotifier<AlbumMediaPage> {
  FutureOr<AlbumMediaPage> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AlbumMediaPage>, AlbumMediaPage>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AlbumMediaPage>, AlbumMediaPage>,
              AsyncValue<AlbumMediaPage>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 选中集合

@ProviderFor(AlbumSelection)
final albumSelectionProvider = AlbumSelectionProvider._();

/// 选中集合
final class AlbumSelectionProvider
    extends $NotifierProvider<AlbumSelection, Set<String>> {
  /// 选中集合
  AlbumSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumSelectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumSelectionHash();

  @$internal
  @override
  AlbumSelection create() => AlbumSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$albumSelectionHash() => r'9ed9f3f8bf1c5cd9e48e2b44beb16538e58d961d';

/// 选中集合

abstract class _$AlbumSelection extends $Notifier<Set<String>> {
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

@ProviderFor(AlbumEdits)
final albumEditsProvider = AlbumEditsProvider._();

final class AlbumEditsProvider
    extends
        $NotifierProvider<
          AlbumEdits,
          ({AlbumMediaUpdate? media, int tagRevision})
        > {
  AlbumEditsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumEditsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumEditsHash();

  @$internal
  @override
  AlbumEdits create() => AlbumEdits();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(
    ({AlbumMediaUpdate? media, int tagRevision}) value,
  ) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<({AlbumMediaUpdate? media, int tagRevision})>(
            value,
          ),
    );
  }
}

String _$albumEditsHash() => r'552e41eaf613b3192434922d3bdbf451ccfaea46';

abstract class _$AlbumEdits
    extends $Notifier<({AlbumMediaUpdate? media, int tagRevision})> {
  ({AlbumMediaUpdate? media, int tagRevision}) build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({AlbumMediaUpdate? media, int tagRevision}),
              ({AlbumMediaUpdate? media, int tagRevision})
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({AlbumMediaUpdate? media, int tagRevision}),
                ({AlbumMediaUpdate? media, int tagRevision})
              >,
              ({AlbumMediaUpdate? media, int tagRevision}),
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）

@ProviderFor(AlbumActions)
final albumActionsProvider = AlbumActionsProvider._();

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
final class AlbumActionsProvider extends $NotifierProvider<AlbumActions, bool> {
  /// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
  AlbumActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumActionsHash();

  @$internal
  @override
  AlbumActions create() => AlbumActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$albumActionsHash() => r'4772ef000fb16cce9fcc305867cee74ff79b0b52';

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）

abstract class _$AlbumActions extends $Notifier<bool> {
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
