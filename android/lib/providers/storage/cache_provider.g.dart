// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 缓存管理Provider

@ProviderFor(CacheManager)
final cacheManagerProvider = CacheManagerProvider._();

/// 缓存管理Provider
final class CacheManagerProvider
    extends $NotifierProvider<CacheManager, CacheState> {
  /// 缓存管理Provider
  CacheManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheManagerHash();

  @$internal
  @override
  CacheManager create() => CacheManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheState>(value),
    );
  }
}

String _$cacheManagerHash() => r'eda86c90d786f39b34d26a22a317e797c0fc53c7';

/// 缓存管理Provider

abstract class _$CacheManager extends $Notifier<CacheState> {
  CacheState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CacheState, CacheState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CacheState, CacheState>,
              CacheState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
