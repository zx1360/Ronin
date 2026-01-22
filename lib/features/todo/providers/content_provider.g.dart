// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentViewTitleHash() => r'9b451001eeccdd623618a8386cb459ea02474e95';

/// 当前视图标题
///
/// Copied from [currentViewTitle].
@ProviderFor(currentViewTitle)
final currentViewTitleProvider = AutoDisposeProvider<String>.internal(
  currentViewTitle,
  name: r'currentViewTitleProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentViewTitleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentViewTitleRef = AutoDisposeProviderRef<String>;
String _$isSmartListViewHash() => r'713cb4dd1c4072d235b51ab9c9b0482cc1733b84';

/// 当前视图是否为智能列表
///
/// Copied from [isSmartListView].
@ProviderFor(isSmartListView)
final isSmartListViewProvider = AutoDisposeProvider<bool>.internal(
  isSmartListView,
  name: r'isSmartListViewProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$isSmartListViewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IsSmartListViewRef = AutoDisposeProviderRef<bool>;
String _$currentSmartListTypeHash() =>
    r'd2d528faaa9ea80fd26b070f0dc35e3a491701d8';

/// 当前智能列表类型（如果是智能列表视图）
///
/// Copied from [currentSmartListType].
@ProviderFor(currentSmartListType)
final currentSmartListTypeProvider =
    AutoDisposeProvider<SmartListType?>.internal(
  currentSmartListType,
  name: r'currentSmartListTypeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentSmartListTypeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentSmartListTypeRef = AutoDisposeProviderRef<SmartListType?>;
String _$currentCustomListIdHash() =>
    r'82058f18ef939e82492dea3bc804452b0b02c1bd';

/// 当前自定义列表 ID（如果是自定义列表视图）
///
/// Copied from [currentCustomListId].
@ProviderFor(currentCustomListId)
final currentCustomListIdProvider = AutoDisposeProvider<String?>.internal(
  currentCustomListId,
  name: r'currentCustomListIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentCustomListIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentCustomListIdRef = AutoDisposeProviderRef<String?>;
String _$currentCustomListHash() => r'4fb95a5e24bfd57bfc0ee60a69b0dd02c5fb7aeb';

/// 当前自定义列表（如果是自定义列表视图）
///
/// Copied from [currentCustomList].
@ProviderFor(currentCustomList)
final currentCustomListProvider = AutoDisposeProvider<TaskList?>.internal(
  currentCustomList,
  name: r'currentCustomListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentCustomListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CurrentCustomListRef = AutoDisposeProviderRef<TaskList?>;
String _$currentViewNotifierHash() =>
    r'c1385e248534f88f1edda1041fc814e2a2a0f496';

/// 当前视图状态
///
/// 存储当前用户正在查看的视图类型（智能列表或自定义列表）
///
/// Copied from [CurrentViewNotifier].
@ProviderFor(CurrentViewNotifier)
final currentViewNotifierProvider =
    AutoDisposeNotifierProvider<CurrentViewNotifier, CurrentView>.internal(
  CurrentViewNotifier.new,
  name: r'currentViewNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentViewNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentViewNotifier = AutoDisposeNotifier<CurrentView>;
String _$contentHash() => r'b84d9c0a05034fcee41d1d9833da9e243bfaee02';

/// @deprecated 使用 [currentViewNotifierProvider] 替代
/// 当前选中的任务列表
///
/// Copied from [Content].
@ProviderFor(Content)
final contentProvider =
    AutoDisposeNotifierProvider<Content, TaskList?>.internal(
  Content.new,
  name: r'contentProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$contentHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Content = AutoDisposeNotifier<TaskList?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
