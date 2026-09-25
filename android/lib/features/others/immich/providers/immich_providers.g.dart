// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'immich_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$immichFilterNotifierHash() =>
    r'3085ef6065e98f72403b52e8678d6587254a035a';

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
String _$immichMediaHash() => r'816bde27fb4cbea36940f509237b1bdd074fba41';

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
String _$immichSelectionHash() => r'5f7caa2197779fa776b3d30b39ec9d51489246c9';

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
String _$immichActionsHash() => r'842d2072731676ba99cff97b3310397659d4c2fb';

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
