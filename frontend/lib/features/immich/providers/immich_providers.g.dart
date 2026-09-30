// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'immich_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$immichFilterNotifierHash() =>
    r'954be08e16d85d8394a6ec841341c694bf73fd1c';

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
String _$immichMediaHash() => r'41281dbcb9e235dc94448d375cc28a1da784417d';

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
String _$immichSelectionHash() => r'52d3f595095f0ef9ea3ca6fb236c95ffc0b1215a';

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
String _$immichActionsHash() => r'd4aaf9b565ef6115896632785f2498eea431e357';

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
