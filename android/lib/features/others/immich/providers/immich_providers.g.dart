// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'immich_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$immichFilterNotifierHash() =>
    r'1a9257ee9a67ab9c8a02d8206638c4abced59ca8';

/// 筛选条件 Provider
///
/// Copied from [ImmichFilterNotifier].
@ProviderFor(ImmichFilterNotifier)
final immichFilterNotifierProvider =
    AutoDisposeNotifierProvider<ImmichFilterNotifier, ImmichFilter>.internal(
  ImmichFilterNotifier.new,
  name: r'immichFilterNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$immichFilterNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImmichFilterNotifier = AutoDisposeNotifier<ImmichFilter>;
String _$immichMediaHash() => r'be23e919382b968d76ffc2f8bf46d920ed28e333';

/// 媒体列表（按当前筛选条件分页拉取, 并把服务端结果写回本地缓存）
///
/// Copied from [ImmichMedia].
@ProviderFor(ImmichMedia)
final immichMediaProvider =
    AutoDisposeAsyncNotifierProvider<ImmichMedia, ImmichMediaPage>.internal(
  ImmichMedia.new,
  name: r'immichMediaProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$immichMediaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImmichMedia = AutoDisposeAsyncNotifier<ImmichMediaPage>;
String _$immichSelectionHash() => r'a0cb5bd73351e136a4e2dd2fc1a93db1f8a4a670';

/// 选中集合
///
/// Copied from [ImmichSelection].
@ProviderFor(ImmichSelection)
final immichSelectionProvider =
    AutoDisposeNotifierProvider<ImmichSelection, Set<String>>.internal(
  ImmichSelection.new,
  name: r'immichSelectionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$immichSelectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImmichSelection = AutoDisposeNotifier<Set<String>>;
String _$immichActionsHash() => r'9c0ef44f0261ebda2b8d128c3e93f60ebe17f1e7';

/// 批量操作状态与动作（在线直达服务端, 成功后刷新列表与标签计数）
///
/// Copied from [ImmichActions].
@ProviderFor(ImmichActions)
final immichActionsProvider =
    AutoDisposeNotifierProvider<ImmichActions, bool>.internal(
  ImmichActions.new,
  name: r'immichActionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$immichActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImmichActions = AutoDisposeNotifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
