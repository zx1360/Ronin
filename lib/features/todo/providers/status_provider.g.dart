// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

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
String _$listWithIdHash() => r'510eac64f33a50ecaa2d0b69381dab46647ebb40';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [listWithId].
@ProviderFor(listWithId)
const listWithIdProvider = ListWithIdFamily();

/// See also [listWithId].
class ListWithIdFamily extends Family<TaskList> {
  /// See also [listWithId].
  const ListWithIdFamily();

  /// See also [listWithId].
  ListWithIdProvider call(
    String listId,
  ) {
    return ListWithIdProvider(
      listId,
    );
  }

  @override
  ListWithIdProvider getProviderOverride(
    covariant ListWithIdProvider provider,
  ) {
    return call(
      provider.listId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'listWithIdProvider';
}

/// See also [listWithId].
class ListWithIdProvider extends AutoDisposeProvider<TaskList> {
  /// See also [listWithId].
  ListWithIdProvider(
    String listId,
  ) : this._internal(
          (ref) => listWithId(
            ref as ListWithIdRef,
            listId,
          ),
          from: listWithIdProvider,
          name: r'listWithIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$listWithIdHash,
          dependencies: ListWithIdFamily._dependencies,
          allTransitiveDependencies:
              ListWithIdFamily._allTransitiveDependencies,
          listId: listId,
        );

  ListWithIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.listId,
  }) : super.internal();

  final String listId;

  @override
  Override overrideWith(
    TaskList Function(ListWithIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListWithIdProvider._internal(
        (ref) => create(ref as ListWithIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        listId: listId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaskList> createElement() {
    return _ListWithIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListWithIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ListWithIdRef on AutoDisposeProviderRef<TaskList> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _ListWithIdProviderElement extends AutoDisposeProviderElement<TaskList>
    with ListWithIdRef {
  _ListWithIdProviderElement(super.provider);

  @override
  String get listId => (origin as ListWithIdProvider).listId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
