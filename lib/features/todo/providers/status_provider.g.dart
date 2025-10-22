// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tasksHash() => r'7cee3ff3ce4feec4d76eb41142fc8059360917f0';

/// See also [tasks].
@ProviderFor(tasks)
final tasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  tasks,
  name: r'tasksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$tasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$taskListHash() => r'a84e3f9b179c95d160a243373865548f04186892';

/// See also [taskList].
@ProviderFor(taskList)
final taskListProvider = AutoDisposeProvider<List<TaskList>>.internal(
  taskList,
  name: r'taskListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$taskListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TaskListRef = AutoDisposeProviderRef<List<TaskList>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
