// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskListBoxHash() => r'e37a9063efcfc9927bbc4e4f283b1fc19a3a7dd2';

/// See also [taskListBox].
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
String _$taskListStreamHash() => r'2afc87c2767676ab7e29048c327b6ec61fc3b50e';

/// See also [taskListStream].
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
