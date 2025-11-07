// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$actionInfosHash() => r'ca897c8694aebf94529f3ec4c5e879d1c388a635';

/// See also [actionInfos].
@ProviderFor(actionInfos)
final actionInfosProvider = AutoDisposeProvider<List<ActionInfo>>.internal(
  actionInfos,
  name: r'actionInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$actionInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ActionInfosRef = AutoDisposeProviderRef<List<ActionInfo>>;
String _$dataServiceHash() => r'fc725827e34398f8f1fbc57153c9eaa6ed3e79be';

/// See also [DataService].
@ProviderFor(DataService)
final dataServiceProvider =
    AutoDisposeNotifierProvider<DataService, Map>.internal(
  DataService.new,
  name: r'dataServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dataServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DataService = AutoDisposeNotifier<Map>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
