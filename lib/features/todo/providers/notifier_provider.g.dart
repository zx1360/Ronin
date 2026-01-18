// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$todoServiceHash() => r'f5c3638373a12ab6c0b132885af0eef06a590eaf';

/// Todo 模块的核心服务
///
/// 提供以下功能：
/// - 任务列表 CRUD 操作
/// - 任务 CRUD 操作
/// - 列表排序管理
///
/// Copied from [TodoService].
@ProviderFor(TodoService)
final todoServiceProvider =
    AutoDisposeNotifierProvider<TodoService, TodoRepository>.internal(
  TodoService.new,
  name: r'todoServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$todoServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TodoService = AutoDisposeNotifier<TodoRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
