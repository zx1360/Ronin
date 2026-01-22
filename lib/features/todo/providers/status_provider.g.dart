// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$allListsHash() => r'39532b61f622e2cde524f44d1172f8871ddfd21a';

/// 所有自定义任务列表（按 order 升序排列）
///
/// Copied from [allLists].
@ProviderFor(allLists)
final allListsProvider = AutoDisposeProvider<List<TaskList>>.internal(
  allLists,
  name: r'allListsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allListsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllListsRef = AutoDisposeProviderRef<List<TaskList>>;
String _$listByIdHash() => r'be5d153d3c5fcf0b8f8243a6420cc19809ea9546';

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
/// Copied from [listById].
@ProviderFor(listById)
const listByIdProvider = ListByIdFamily();

/// 根据列表 ID 获取任务列表
///
/// Copied from [listById].
class ListByIdFamily extends Family<TaskList?> {
  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listById].
  const ListByIdFamily();

  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listById].
  ListByIdProvider call(
    String listId,
  ) {
    return ListByIdProvider(
      listId,
    );
  }

  @override
  ListByIdProvider getProviderOverride(
    covariant ListByIdProvider provider,
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
  String? get name => r'listByIdProvider';
}

/// 根据列表 ID 获取任务列表
///
/// Copied from [listById].
class ListByIdProvider extends AutoDisposeProvider<TaskList?> {
  /// 根据列表 ID 获取任务列表
  ///
  /// Copied from [listById].
  ListByIdProvider(
    String listId,
  ) : this._internal(
          (ref) => listById(
            ref as ListByIdRef,
            listId,
          ),
          from: listByIdProvider,
          name: r'listByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$listByIdHash,
          dependencies: ListByIdFamily._dependencies,
          allTransitiveDependencies: ListByIdFamily._allTransitiveDependencies,
          listId: listId,
        );

  ListByIdProvider._internal(
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
    TaskList? Function(ListByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ListByIdProvider._internal(
        (ref) => create(ref as ListByIdRef),
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
  AutoDisposeProviderElement<TaskList?> createElement() {
    return _ListByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ListByIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ListByIdRef on AutoDisposeProviderRef<TaskList?> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _ListByIdProviderElement extends AutoDisposeProviderElement<TaskList?>
    with ListByIdRef {
  _ListByIdProviderElement(super.provider);

  @override
  String get listId => (origin as ListByIdProvider).listId;
}

String _$defaultTaskListHash() => r'f828d8e883e0c7ce83973d0fd78667ae0f0b83c6';

/// 获取默认"任务"列表
///
/// Copied from [defaultTaskList].
@ProviderFor(defaultTaskList)
final defaultTaskListProvider = AutoDisposeProvider<TaskList?>.internal(
  defaultTaskList,
  name: r'defaultTaskListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$defaultTaskListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DefaultTaskListRef = AutoDisposeProviderRef<TaskList?>;
String _$allTasksHash() => r'bef3377fbeb6355b85759d7df21b2a60b388c0fd';

/// 所有任务（响应式）
///
/// Copied from [allTasks].
@ProviderFor(allTasks)
final allTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  allTasks,
  name: r'allTasksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$taskByIdHash() => r'3b4828fbd701cc29a8f2daddfe6822a5754c6d44';

/// 根据任务 ID 获取任务
///
/// Copied from [taskById].
@ProviderFor(taskById)
const taskByIdProvider = TaskByIdFamily();

/// 根据任务 ID 获取任务
///
/// Copied from [taskById].
class TaskByIdFamily extends Family<TodoTask?> {
  /// 根据任务 ID 获取任务
  ///
  /// Copied from [taskById].
  const TaskByIdFamily();

  /// 根据任务 ID 获取任务
  ///
  /// Copied from [taskById].
  TaskByIdProvider call(
    String taskId,
  ) {
    return TaskByIdProvider(
      taskId,
    );
  }

  @override
  TaskByIdProvider getProviderOverride(
    covariant TaskByIdProvider provider,
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
  String? get name => r'taskByIdProvider';
}

/// 根据任务 ID 获取任务
///
/// Copied from [taskById].
class TaskByIdProvider extends AutoDisposeProvider<TodoTask?> {
  /// 根据任务 ID 获取任务
  ///
  /// Copied from [taskById].
  TaskByIdProvider(
    String taskId,
  ) : this._internal(
          (ref) => taskById(
            ref as TaskByIdRef,
            taskId,
          ),
          from: taskByIdProvider,
          name: r'taskByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$taskByIdHash,
          dependencies: TaskByIdFamily._dependencies,
          allTransitiveDependencies: TaskByIdFamily._allTransitiveDependencies,
          taskId: taskId,
        );

  TaskByIdProvider._internal(
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
    TodoTask? Function(TaskByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TaskByIdProvider._internal(
        (ref) => create(ref as TaskByIdRef),
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
  AutoDisposeProviderElement<TodoTask?> createElement() {
    return _TaskByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskByIdProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TaskByIdRef on AutoDisposeProviderRef<TodoTask?> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _TaskByIdProviderElement extends AutoDisposeProviderElement<TodoTask?>
    with TaskByIdRef {
  _TaskByIdProviderElement(super.provider);

  @override
  String get taskId => (origin as TaskByIdProvider).taskId;
}

String _$tasksByListIdHash() => r'f0ac38d0f707d9209e5f283dba0cb28f4dfc196e';

/// 指定列表的任务
///
/// Copied from [tasksByListId].
@ProviderFor(tasksByListId)
const tasksByListIdProvider = TasksByListIdFamily();

/// 指定列表的任务
///
/// Copied from [tasksByListId].
class TasksByListIdFamily extends Family<List<TodoTask>> {
  /// 指定列表的任务
  ///
  /// Copied from [tasksByListId].
  const TasksByListIdFamily();

  /// 指定列表的任务
  ///
  /// Copied from [tasksByListId].
  TasksByListIdProvider call(
    String listId,
  ) {
    return TasksByListIdProvider(
      listId,
    );
  }

  @override
  TasksByListIdProvider getProviderOverride(
    covariant TasksByListIdProvider provider,
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
  String? get name => r'tasksByListIdProvider';
}

/// 指定列表的任务
///
/// Copied from [tasksByListId].
class TasksByListIdProvider extends AutoDisposeProvider<List<TodoTask>> {
  /// 指定列表的任务
  ///
  /// Copied from [tasksByListId].
  TasksByListIdProvider(
    String listId,
  ) : this._internal(
          (ref) => tasksByListId(
            ref as TasksByListIdRef,
            listId,
          ),
          from: tasksByListIdProvider,
          name: r'tasksByListIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$tasksByListIdHash,
          dependencies: TasksByListIdFamily._dependencies,
          allTransitiveDependencies:
              TasksByListIdFamily._allTransitiveDependencies,
          listId: listId,
        );

  TasksByListIdProvider._internal(
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
    List<TodoTask> Function(TasksByListIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TasksByListIdProvider._internal(
        (ref) => create(ref as TasksByListIdRef),
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
  AutoDisposeProviderElement<List<TodoTask>> createElement() {
    return _TasksByListIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksByListIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin TasksByListIdRef on AutoDisposeProviderRef<List<TodoTask>> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _TasksByListIdProviderElement
    extends AutoDisposeProviderElement<List<TodoTask>> with TasksByListIdRef {
  _TasksByListIdProviderElement(super.provider);

  @override
  String get listId => (origin as TasksByListIdProvider).listId;
}

String _$incompleteTaskCountHash() =>
    r'83b853f526f75ea67f4ae1880813c2ade3a49dfd';

/// 指定列表的未完成任务数量
///
/// Copied from [incompleteTaskCount].
@ProviderFor(incompleteTaskCount)
const incompleteTaskCountProvider = IncompleteTaskCountFamily();

/// 指定列表的未完成任务数量
///
/// Copied from [incompleteTaskCount].
class IncompleteTaskCountFamily extends Family<int> {
  /// 指定列表的未完成任务数量
  ///
  /// Copied from [incompleteTaskCount].
  const IncompleteTaskCountFamily();

  /// 指定列表的未完成任务数量
  ///
  /// Copied from [incompleteTaskCount].
  IncompleteTaskCountProvider call(
    String listId,
  ) {
    return IncompleteTaskCountProvider(
      listId,
    );
  }

  @override
  IncompleteTaskCountProvider getProviderOverride(
    covariant IncompleteTaskCountProvider provider,
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
  String? get name => r'incompleteTaskCountProvider';
}

/// 指定列表的未完成任务数量
///
/// Copied from [incompleteTaskCount].
class IncompleteTaskCountProvider extends AutoDisposeProvider<int> {
  /// 指定列表的未完成任务数量
  ///
  /// Copied from [incompleteTaskCount].
  IncompleteTaskCountProvider(
    String listId,
  ) : this._internal(
          (ref) => incompleteTaskCount(
            ref as IncompleteTaskCountRef,
            listId,
          ),
          from: incompleteTaskCountProvider,
          name: r'incompleteTaskCountProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$incompleteTaskCountHash,
          dependencies: IncompleteTaskCountFamily._dependencies,
          allTransitiveDependencies:
              IncompleteTaskCountFamily._allTransitiveDependencies,
          listId: listId,
        );

  IncompleteTaskCountProvider._internal(
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
    int Function(IncompleteTaskCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IncompleteTaskCountProvider._internal(
        (ref) => create(ref as IncompleteTaskCountRef),
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
  AutoDisposeProviderElement<int> createElement() {
    return _IncompleteTaskCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncompleteTaskCountProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin IncompleteTaskCountRef on AutoDisposeProviderRef<int> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _IncompleteTaskCountProviderElement
    extends AutoDisposeProviderElement<int> with IncompleteTaskCountRef {
  _IncompleteTaskCountProviderElement(super.provider);

  @override
  String get listId => (origin as IncompleteTaskCountProvider).listId;
}

String _$myDayTasksHash() => r'2ecdd27f7950389de4de61ab35279d1b080d74d0';

/// "我的一天"任务（今天添加到我的一天且未完成）
///
/// Copied from [myDayTasks].
@ProviderFor(myDayTasks)
final myDayTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  myDayTasks,
  name: r'myDayTasksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myDayTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MyDayTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$myDayTaskCountHash() => r'd29230098591198ef98daf54aaad3a4f3a31c87f';

/// "我的一天"任务数量
///
/// Copied from [myDayTaskCount].
@ProviderFor(myDayTaskCount)
final myDayTaskCountProvider = AutoDisposeProvider<int>.internal(
  myDayTaskCount,
  name: r'myDayTaskCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myDayTaskCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MyDayTaskCountRef = AutoDisposeProviderRef<int>;
String _$importantTasksHash() => r'0989e064e8b037d825d27a95814053853baf04eb';

/// "重要"任务（标记为重要且未完成）
///
/// Copied from [importantTasks].
@ProviderFor(importantTasks)
final importantTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  importantTasks,
  name: r'importantTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$importantTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ImportantTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$importantTaskCountHash() =>
    r'2700ae989018d43882b28f6264058bc9c1fa1991';

/// "重要"任务数量
///
/// Copied from [importantTaskCount].
@ProviderFor(importantTaskCount)
final importantTaskCountProvider = AutoDisposeProvider<int>.internal(
  importantTaskCount,
  name: r'importantTaskCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$importantTaskCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ImportantTaskCountRef = AutoDisposeProviderRef<int>;
String _$plannedTasksHash() => r'0787c4b6e17958c3402e8ecf8e4f5623c4d862c4';

/// "计划内"任务（有截止日期且未完成）
///
/// Copied from [plannedTasks].
@ProviderFor(plannedTasks)
final plannedTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  plannedTasks,
  name: r'plannedTasksProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$plannedTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PlannedTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$plannedTaskCountHash() => r'dc5de6756647353fcc254b7a378336091f0495dd';

/// "计划内"任务数量
///
/// Copied from [plannedTaskCount].
@ProviderFor(plannedTaskCount)
final plannedTaskCountProvider = AutoDisposeProvider<int>.internal(
  plannedTaskCount,
  name: r'plannedTaskCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$plannedTaskCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef PlannedTaskCountRef = AutoDisposeProviderRef<int>;
String _$allIncompleteTasksHash() =>
    r'a2d935c6b1bd478081a6770e120694559e12e31b';

/// "全部"任务（所有未完成任务）
///
/// Copied from [allIncompleteTasks].
@ProviderFor(allIncompleteTasks)
final allIncompleteTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  allIncompleteTasks,
  name: r'allIncompleteTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allIncompleteTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllIncompleteTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$allIncompleteTaskCountHash() =>
    r'd63834e8cc1287a5bf012f3b757bf3ab3e84a3cf';

/// "全部"任务数量
///
/// Copied from [allIncompleteTaskCount].
@ProviderFor(allIncompleteTaskCount)
final allIncompleteTaskCountProvider = AutoDisposeProvider<int>.internal(
  allIncompleteTaskCount,
  name: r'allIncompleteTaskCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allIncompleteTaskCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllIncompleteTaskCountRef = AutoDisposeProviderRef<int>;
String _$completedTasksHash() => r'bac9b26780f7bc512839060da4728fd327a74113';

/// 已完成任务
///
/// Copied from [completedTasks].
@ProviderFor(completedTasks)
final completedTasksProvider = AutoDisposeProvider<List<TodoTask>>.internal(
  completedTasks,
  name: r'completedTasksProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$completedTasksHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CompletedTasksRef = AutoDisposeProviderRef<List<TodoTask>>;
String _$completedTasksByListIdHash() =>
    r'251fdb048d4ca14aadd0cf0c56c7614b2c2f9467';

/// 指定列表的已完成任务
///
/// Copied from [completedTasksByListId].
@ProviderFor(completedTasksByListId)
const completedTasksByListIdProvider = CompletedTasksByListIdFamily();

/// 指定列表的已完成任务
///
/// Copied from [completedTasksByListId].
class CompletedTasksByListIdFamily extends Family<List<TodoTask>> {
  /// 指定列表的已完成任务
  ///
  /// Copied from [completedTasksByListId].
  const CompletedTasksByListIdFamily();

  /// 指定列表的已完成任务
  ///
  /// Copied from [completedTasksByListId].
  CompletedTasksByListIdProvider call(
    String listId,
  ) {
    return CompletedTasksByListIdProvider(
      listId,
    );
  }

  @override
  CompletedTasksByListIdProvider getProviderOverride(
    covariant CompletedTasksByListIdProvider provider,
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
  String? get name => r'completedTasksByListIdProvider';
}

/// 指定列表的已完成任务
///
/// Copied from [completedTasksByListId].
class CompletedTasksByListIdProvider
    extends AutoDisposeProvider<List<TodoTask>> {
  /// 指定列表的已完成任务
  ///
  /// Copied from [completedTasksByListId].
  CompletedTasksByListIdProvider(
    String listId,
  ) : this._internal(
          (ref) => completedTasksByListId(
            ref as CompletedTasksByListIdRef,
            listId,
          ),
          from: completedTasksByListIdProvider,
          name: r'completedTasksByListIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$completedTasksByListIdHash,
          dependencies: CompletedTasksByListIdFamily._dependencies,
          allTransitiveDependencies:
              CompletedTasksByListIdFamily._allTransitiveDependencies,
          listId: listId,
        );

  CompletedTasksByListIdProvider._internal(
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
    List<TodoTask> Function(CompletedTasksByListIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CompletedTasksByListIdProvider._internal(
        (ref) => create(ref as CompletedTasksByListIdRef),
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
  AutoDisposeProviderElement<List<TodoTask>> createElement() {
    return _CompletedTasksByListIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CompletedTasksByListIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CompletedTasksByListIdRef on AutoDisposeProviderRef<List<TodoTask>> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _CompletedTasksByListIdProviderElement
    extends AutoDisposeProviderElement<List<TodoTask>>
    with CompletedTasksByListIdRef {
  _CompletedTasksByListIdProviderElement(super.provider);

  @override
  String get listId => (origin as CompletedTasksByListIdProvider).listId;
}

String _$incompleteTasksByListIdHash() =>
    r'3ad768cbbc038579c9960b4aee4cc1d2ebcaad43';

/// 指定列表的未完成任务
///
/// Copied from [incompleteTasksByListId].
@ProviderFor(incompleteTasksByListId)
const incompleteTasksByListIdProvider = IncompleteTasksByListIdFamily();

/// 指定列表的未完成任务
///
/// Copied from [incompleteTasksByListId].
class IncompleteTasksByListIdFamily extends Family<List<TodoTask>> {
  /// 指定列表的未完成任务
  ///
  /// Copied from [incompleteTasksByListId].
  const IncompleteTasksByListIdFamily();

  /// 指定列表的未完成任务
  ///
  /// Copied from [incompleteTasksByListId].
  IncompleteTasksByListIdProvider call(
    String listId,
  ) {
    return IncompleteTasksByListIdProvider(
      listId,
    );
  }

  @override
  IncompleteTasksByListIdProvider getProviderOverride(
    covariant IncompleteTasksByListIdProvider provider,
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
  String? get name => r'incompleteTasksByListIdProvider';
}

/// 指定列表的未完成任务
///
/// Copied from [incompleteTasksByListId].
class IncompleteTasksByListIdProvider
    extends AutoDisposeProvider<List<TodoTask>> {
  /// 指定列表的未完成任务
  ///
  /// Copied from [incompleteTasksByListId].
  IncompleteTasksByListIdProvider(
    String listId,
  ) : this._internal(
          (ref) => incompleteTasksByListId(
            ref as IncompleteTasksByListIdRef,
            listId,
          ),
          from: incompleteTasksByListIdProvider,
          name: r'incompleteTasksByListIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$incompleteTasksByListIdHash,
          dependencies: IncompleteTasksByListIdFamily._dependencies,
          allTransitiveDependencies:
              IncompleteTasksByListIdFamily._allTransitiveDependencies,
          listId: listId,
        );

  IncompleteTasksByListIdProvider._internal(
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
    List<TodoTask> Function(IncompleteTasksByListIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: IncompleteTasksByListIdProvider._internal(
        (ref) => create(ref as IncompleteTasksByListIdRef),
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
  AutoDisposeProviderElement<List<TodoTask>> createElement() {
    return _IncompleteTasksByListIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is IncompleteTasksByListIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin IncompleteTasksByListIdRef on AutoDisposeProviderRef<List<TodoTask>> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _IncompleteTasksByListIdProviderElement
    extends AutoDisposeProviderElement<List<TodoTask>>
    with IncompleteTasksByListIdRef {
  _IncompleteTasksByListIdProviderElement(super.provider);

  @override
  String get listId => (origin as IncompleteTasksByListIdProvider).listId;
}

String _$taskListHash() => r'693fc02969c0eef1a02396c7a82c13f98fe95b26';

/// @deprecated 使用 [allListsProvider] 替代
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
String _$listWithIdHash() => r'26a4b728c7ba3519c3be74db08779a68098ed547';

/// @deprecated 使用 [listByIdProvider] 替代
///
/// Copied from [listWithId].
@ProviderFor(listWithId)
const listWithIdProvider = ListWithIdFamily();

/// @deprecated 使用 [listByIdProvider] 替代
///
/// Copied from [listWithId].
class ListWithIdFamily extends Family<TaskList> {
  /// @deprecated 使用 [listByIdProvider] 替代
  ///
  /// Copied from [listWithId].
  const ListWithIdFamily();

  /// @deprecated 使用 [listByIdProvider] 替代
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

/// @deprecated 使用 [listByIdProvider] 替代
///
/// Copied from [listWithId].
class ListWithIdProvider extends AutoDisposeProvider<TaskList> {
  /// @deprecated 使用 [listByIdProvider] 替代
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

/// @deprecated 使用 [defaultTaskListProvider] 替代
///
/// Copied from [listWithName].
@ProviderFor(listWithName)
const listWithNameProvider = ListWithNameFamily();

/// @deprecated 使用 [defaultTaskListProvider] 替代
///
/// Copied from [listWithName].
class ListWithNameFamily extends Family<TaskList> {
  /// @deprecated 使用 [defaultTaskListProvider] 替代
  ///
  /// Copied from [listWithName].
  const ListWithNameFamily();

  /// @deprecated 使用 [defaultTaskListProvider] 替代
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

/// @deprecated 使用 [defaultTaskListProvider] 替代
///
/// Copied from [listWithName].
class ListWithNameProvider extends AutoDisposeProvider<TaskList> {
  /// @deprecated 使用 [defaultTaskListProvider] 替代
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

String _$listWithTaskIdHash() => r'593e32579c1aee6694c44de0516af52d4a9f3019';

/// @deprecated 移除 - 任务现在独立存储
///
/// Copied from [listWithTaskId].
@ProviderFor(listWithTaskId)
const listWithTaskIdProvider = ListWithTaskIdFamily();

/// @deprecated 移除 - 任务现在独立存储
///
/// Copied from [listWithTaskId].
class ListWithTaskIdFamily extends Family<TaskList> {
  /// @deprecated 移除 - 任务现在独立存储
  ///
  /// Copied from [listWithTaskId].
  const ListWithTaskIdFamily();

  /// @deprecated 移除 - 任务现在独立存储
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

/// @deprecated 移除 - 任务现在独立存储
///
/// Copied from [listWithTaskId].
class ListWithTaskIdProvider extends AutoDisposeProvider<TaskList> {
  /// @deprecated 移除 - 任务现在独立存储
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

String _$availableListsHash() => r'ba2042481080ea3f46094c36853b58aea33b5af3';

/// 新增任务时可供选择的任务列表
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
