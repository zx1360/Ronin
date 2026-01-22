// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskListBoxHash() => r'e37a9063efcfc9927bbc4e4f283b1fc19a3a7dd2';

/// 任务列表的 Hive Box
///
/// Copied from [taskListBox].
@ProviderFor(taskListBox)
final taskListBoxProvider = AutoDisposeProvider<Box<TaskList>>.internal(
  taskListBox,
  name: r'taskListBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$taskListBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TaskListBoxRef = AutoDisposeProviderRef<Box<TaskList>>;
String _$taskListStreamHash() => r'f900836febfee8c40f515781a29e63fba7660cdb';

/// 任务列表的响应式流
///
/// Copied from [taskListStream].
@ProviderFor(taskListStream)
final taskListStreamProvider =
    AutoDisposeStreamProvider<List<TaskList>>.internal(
  taskListStream,
  name: r'taskListStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$taskListStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TaskListStreamRef = AutoDisposeStreamProviderRef<List<TaskList>>;
String _$todoTaskBoxHash() => r'77743b143ff024e3d12d1bd0f62af3ab4062b499';

/// 任务的 Hive Box
///
/// Copied from [todoTaskBox].
@ProviderFor(todoTaskBox)
final todoTaskBoxProvider = AutoDisposeProvider<Box<TodoTask>>.internal(
  todoTaskBox,
  name: r'todoTaskBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$todoTaskBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TodoTaskBoxRef = AutoDisposeProviderRef<Box<TodoTask>>;
String _$todoTaskStreamHash() => r'11a49caba97f7b3bf563305bf30977f4fdf98294';

/// 任务的响应式流
///
/// Copied from [todoTaskStream].
@ProviderFor(todoTaskStream)
final todoTaskStreamProvider =
    AutoDisposeStreamProvider<List<TodoTask>>.internal(
  todoTaskStream,
  name: r'todoTaskStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todoTaskStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TodoTaskStreamRef = AutoDisposeStreamProviderRef<List<TodoTask>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
