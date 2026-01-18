// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskListHash() => r'f4dad0b370bd7dd654e8746d4f16523c33fffb6d';

/// 所有任务列表（按 order 升序排列）
///
/// Copied from [taskList].
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
String _$listWithIdHash() => r'10ecefcd6eec38380c50711b63a9934d5201e036';

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

/// 根据列表 ID 获取任务列表
///
/// Copied from [listWithId].
@ProviderFor(listWithId)
const listWithIdProvider = ListWithIdFamily();

/// 根据列表 ID 获取任务列表
///
/// Copied from [listWithId].
class ListWithIdFamily extends Family<TaskList> {
  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listWithId].
  const ListWithIdFamily();

  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listWithId].
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

/// 根据列表 ID 获取任务列表
///
/// Copied from [listWithId].
class ListWithIdProvider extends AutoDisposeProvider<TaskList> {
  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listWithId].
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

String _$listWithNameHash() => r'2440c6c68581bc56791ca45714ad1dbdc0cf306b';

/// 根据列表名称获取默认任务列表
///
/// Copied from [listWithName].
@ProviderFor(listWithName)
const listWithNameProvider = ListWithNameFamily();

/// 根据列表名称获取默认任务列表
///
/// Copied from [listWithName].
class ListWithNameFamily extends Family<TaskList> {
  /// 根据列表名称获取默认任务列表
  ///
  /// Copied from [listWithName].
  const ListWithNameFamily();

  /// 根据列表名称获取默认任务列表
  ///
  /// Copied from [listWithName].
  ListWithNameProvider call(
    String listName,
  ) {
    return ListWithNameProvider(
      listName,
    );
  }

  @override
  ListWithNameProvider getProviderOverride(
    covariant ListWithNameProvider provider,
  ) {
    return call(
      provider.listName,
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
  String? get name => r'listWithNameProvider';
}

/// 根据列表名称获取默认任务列表
///
/// Copied from [listWithName].
class ListWithNameProvider extends AutoDisposeProvider<TaskList> {
  /// 根据列表名称获取默认任务列表
  ///
  /// Copied from [listWithName].
  ListWithNameProvider(
    String listName,
  ) : this._internal(
          (ref) => listWithName(
            ref as ListWithNameRef,
            listName,
          ),
          from: listWithNameProvider,
          name: r'listWithNameProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$listWithNameHash,
          dependencies: ListWithNameFamily._dependencies,
          allTransitiveDependencies:
              ListWithNameFamily._allTransitiveDependencies,
          listName: listName,
        );

  ListWithNameProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.listName,
  }) : super.internal();

  final String listName;

  @override
  Override overrideWith(
    TaskList Function(ListWithNameRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListWithNameProvider._internal(
        (ref) => create(ref as ListWithNameRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        listName: listName,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaskList> createElement() {
    return _ListWithNameProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListWithNameProvider && other.listName == listName;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listName.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ListWithNameRef on AutoDisposeProviderRef<TaskList> {
  /// The parameter `listName` of this provider.
  String get listName;
}

class _ListWithNameProviderElement extends AutoDisposeProviderElement<TaskList>
    with ListWithNameRef {
  _ListWithNameProviderElement(super.provider);

  @override
  String get listName => (origin as ListWithNameProvider).listName;
}

String _$listWithTaskIdHash() => r'b8ad400dc38a48dde0fcfcecfd0a07d9c07077a7';

/// 根据任务 ID 找到其所属的任务列表
///
/// Copied from [listWithTaskId].
@ProviderFor(listWithTaskId)
const listWithTaskIdProvider = ListWithTaskIdFamily();

/// 根据任务 ID 找到其所属的任务列表
///
/// Copied from [listWithTaskId].
class ListWithTaskIdFamily extends Family<TaskList> {
  /// 根据任务 ID 找到其所属的任务列表
  ///
  /// Copied from [listWithTaskId].
  const ListWithTaskIdFamily();

  /// 根据任务 ID 找到其所属的任务列表
  ///
  /// Copied from [listWithTaskId].
  ListWithTaskIdProvider call(
    String taskId,
  ) {
    return ListWithTaskIdProvider(
      taskId,
    );
  }

  @override
  ListWithTaskIdProvider getProviderOverride(
    covariant ListWithTaskIdProvider provider,
  ) {
    return call(
      provider.taskId,
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
  String? get name => r'listWithTaskIdProvider';
}

/// 根据任务 ID 找到其所属的任务列表
///
/// Copied from [listWithTaskId].
class ListWithTaskIdProvider extends AutoDisposeProvider<TaskList> {
  /// 根据任务 ID 找到其所属的任务列表
  ///
  /// Copied from [listWithTaskId].
  ListWithTaskIdProvider(
    String taskId,
  ) : this._internal(
          (ref) => listWithTaskId(
            ref as ListWithTaskIdRef,
            taskId,
          ),
          from: listWithTaskIdProvider,
          name: r'listWithTaskIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$listWithTaskIdHash,
          dependencies: ListWithTaskIdFamily._dependencies,
          allTransitiveDependencies:
              ListWithTaskIdFamily._allTransitiveDependencies,
          taskId: taskId,
        );

  ListWithTaskIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  Override overrideWith(
    TaskList Function(ListWithTaskIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListWithTaskIdProvider._internal(
        (ref) => create(ref as ListWithTaskIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<TaskList> createElement() {
    return _ListWithTaskIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListWithTaskIdProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ListWithTaskIdRef on AutoDisposeProviderRef<TaskList> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _ListWithTaskIdProviderElement
    extends AutoDisposeProviderElement<TaskList> with ListWithTaskIdRef {
  _ListWithTaskIdProviderElement(super.provider);

  @override
  String get taskId => (origin as ListWithTaskIdProvider).taskId;
}

String _$availableListsHash() => r'297274bf137a5fc313a50bd60404b01f9d9e8ca3';

/// 新增任务时可供选择的任务列表
///
/// 包含默认的"任务"列表和所有非默认列表。
///
/// Copied from [availableLists].
@ProviderFor(availableLists)
final availableListsProvider = AutoDisposeProvider<List<TaskList>>.internal(
  availableLists,
  name: r'availableListsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$availableListsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AvailableListsRef = AutoDisposeProviderRef<List<TaskList>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
