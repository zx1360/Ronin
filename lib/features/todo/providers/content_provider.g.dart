// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$contentHash() => r'6520d27334f7017158e723c60ffa68ad73acfeda';

/// 当前选中的任务列表
///
/// 用于 Todo 页面显示当前正在查看的任务列表。
///
/// **重命名说明**: 原名 `Content`，为提高可读性可考虑重命名为 `SelectedTaskList`。
/// 生成的 provider 名称保持 `contentProvider` 以保持向后兼容。
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
