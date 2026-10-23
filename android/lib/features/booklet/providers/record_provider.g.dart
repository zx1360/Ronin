// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordsByStyleIdHash() => r'99dc7231a71c5fa4bdcec015a3e57abe2c21ce57';

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

/// 根据 styleId 返回关联的倒序排列的所有 Records
///
/// Copied from [recordsByStyleId].
@ProviderFor(recordsByStyleId)
const recordsByStyleIdProvider = RecordsByStyleIdFamily();

/// 根据 styleId 返回关联的倒序排列的所有 Records
///
/// Copied from [recordsByStyleId].
class RecordsByStyleIdFamily extends Family<List<Record>> {
  /// 根据 styleId 返回关联的倒序排列的所有 Records
  ///
  /// Copied from [recordsByStyleId].
  const RecordsByStyleIdFamily();

  /// 根据 styleId 返回关联的倒序排列的所有 Records
  ///
  /// Copied from [recordsByStyleId].
  RecordsByStyleIdProvider call(
    String styleId,
  ) {
    return RecordsByStyleIdProvider(
      styleId,
    );
  }

  @override
  RecordsByStyleIdProvider getProviderOverride(
    covariant RecordsByStyleIdProvider provider,
  ) {
    return call(
      provider.styleId,
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
  String? get name => r'recordsByStyleIdProvider';
}

/// 根据 styleId 返回关联的倒序排列的所有 Records
///
/// Copied from [recordsByStyleId].
class RecordsByStyleIdProvider extends AutoDisposeProvider<List<Record>> {
  /// 根据 styleId 返回关联的倒序排列的所有 Records
  ///
  /// Copied from [recordsByStyleId].
  RecordsByStyleIdProvider(
    String styleId,
  ) : this._internal(
          (ref) => recordsByStyleId(
            ref as RecordsByStyleIdRef,
            styleId,
          ),
          from: recordsByStyleIdProvider,
          name: r'recordsByStyleIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$recordsByStyleIdHash,
          dependencies: RecordsByStyleIdFamily._dependencies,
          allTransitiveDependencies:
              RecordsByStyleIdFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  RecordsByStyleIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.styleId,
  }) : super.internal();

  final String styleId;

  @override
  Override overrideWith(
    List<Record> Function(RecordsByStyleIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecordsByStyleIdProvider._internal(
        (ref) => create(ref as RecordsByStyleIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        styleId: styleId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<List<Record>> createElement() {
    return _RecordsByStyleIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordsByStyleIdProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RecordsByStyleIdRef on AutoDisposeProviderRef<List<Record>> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _RecordsByStyleIdProviderElement
    extends AutoDisposeProviderElement<List<Record>> with RecordsByStyleIdRef {
  _RecordsByStyleIdProviderElement(super.provider);

  @override
  String get styleId => (origin as RecordsByStyleIdProvider).styleId;
}

String _$recordByDateHash() => r'fb1f68f0b1c995d8e6ba5f5edc72e282bef9ed06';

/// 根据日期获取 Record
///
/// Copied from [recordByDate].
@ProviderFor(recordByDate)
const recordByDateProvider = RecordByDateFamily();

/// 根据日期获取 Record
///
/// Copied from [recordByDate].
class RecordByDateFamily extends Family<Record?> {
  /// 根据日期获取 Record
  ///
  /// Copied from [recordByDate].
  const RecordByDateFamily();

  /// 根据日期获取 Record
  ///
  /// Copied from [recordByDate].
  RecordByDateProvider call({
    required DateTime targetDate,
  }) {
    return RecordByDateProvider(
      targetDate: targetDate,
    );
  }

  @override
  RecordByDateProvider getProviderOverride(
    covariant RecordByDateProvider provider,
  ) {
    return call(
      targetDate: provider.targetDate,
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
  String? get name => r'recordByDateProvider';
}

/// 根据日期获取 Record
///
/// Copied from [recordByDate].
class RecordByDateProvider extends AutoDisposeProvider<Record?> {
  /// 根据日期获取 Record
  ///
  /// Copied from [recordByDate].
  RecordByDateProvider({
    required DateTime targetDate,
  }) : this._internal(
          (ref) => recordByDate(
            ref as RecordByDateRef,
            targetDate: targetDate,
          ),
          from: recordByDateProvider,
          name: r'recordByDateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$recordByDateHash,
          dependencies: RecordByDateFamily._dependencies,
          allTransitiveDependencies:
              RecordByDateFamily._allTransitiveDependencies,
          targetDate: targetDate,
        );

  RecordByDateProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetDate,
  }) : super.internal();

  final DateTime targetDate;

  @override
  Override overrideWith(
    Record? Function(RecordByDateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecordByDateProvider._internal(
        (ref) => create(ref as RecordByDateRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetDate: targetDate,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Record?> createElement() {
    return _RecordByDateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordByDateProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RecordByDateRef on AutoDisposeProviderRef<Record?> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _RecordByDateProviderElement extends AutoDisposeProviderElement<Record?>
    with RecordByDateRef {
  _RecordByDateProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as RecordByDateProvider).targetDate;
}

String _$allTaskCompletionCountsHash() =>
    r'f7023265adac617feaf89bf3bf24852eb5734cfe';

/// 各任务的完成次数，忽略不属于该计划的任务。
///
/// Copied from [allTaskCompletionCounts].
@ProviderFor(allTaskCompletionCounts)
const allTaskCompletionCountsProvider = AllTaskCompletionCountsFamily();

/// 各任务的完成次数，忽略不属于该计划的任务。
///
/// Copied from [allTaskCompletionCounts].
class AllTaskCompletionCountsFamily extends Family<Map<String, int>> {
  /// 各任务的完成次数，忽略不属于该计划的任务。
  ///
  /// Copied from [allTaskCompletionCounts].
  const AllTaskCompletionCountsFamily();

  /// 各任务的完成次数，忽略不属于该计划的任务。
  ///
  /// Copied from [allTaskCompletionCounts].
  AllTaskCompletionCountsProvider call(
    String styleId,
  ) {
    return AllTaskCompletionCountsProvider(
      styleId,
    );
  }

  @override
  AllTaskCompletionCountsProvider getProviderOverride(
    covariant AllTaskCompletionCountsProvider provider,
  ) {
    return call(
      provider.styleId,
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
  String? get name => r'allTaskCompletionCountsProvider';
}

/// 各任务的完成次数，忽略不属于该计划的任务。
///
/// Copied from [allTaskCompletionCounts].
class AllTaskCompletionCountsProvider
    extends AutoDisposeProvider<Map<String, int>> {
  /// 各任务的完成次数，忽略不属于该计划的任务。
  ///
  /// Copied from [allTaskCompletionCounts].
  AllTaskCompletionCountsProvider(
    String styleId,
  ) : this._internal(
          (ref) => allTaskCompletionCounts(
            ref as AllTaskCompletionCountsRef,
            styleId,
          ),
          from: allTaskCompletionCountsProvider,
          name: r'allTaskCompletionCountsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$allTaskCompletionCountsHash,
          dependencies: AllTaskCompletionCountsFamily._dependencies,
          allTransitiveDependencies:
              AllTaskCompletionCountsFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  AllTaskCompletionCountsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.styleId,
  }) : super.internal();

  final String styleId;

  @override
  Override overrideWith(
    Map<String, int> Function(AllTaskCompletionCountsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AllTaskCompletionCountsProvider._internal(
        (ref) => create(ref as AllTaskCompletionCountsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        styleId: styleId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<Map<String, int>> createElement() {
    return _AllTaskCompletionCountsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AllTaskCompletionCountsProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AllTaskCompletionCountsRef on AutoDisposeProviderRef<Map<String, int>> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _AllTaskCompletionCountsProviderElement
    extends AutoDisposeProviderElement<Map<String, int>>
    with AllTaskCompletionCountsRef {
  _AllTaskCompletionCountsProviderElement(super.provider);

  @override
  String get styleId => (origin as AllTaskCompletionCountsProvider).styleId;
}

String _$currentStreakHash() => r'62126411ce6b4de089488da19d42feec1c63eb3b';

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
///
/// Copied from [currentStreak].
@ProviderFor(currentStreak)
const currentStreakProvider = CurrentStreakFamily();

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
///
/// Copied from [currentStreak].
class CurrentStreakFamily extends Family<int> {
  /// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
  ///
  /// Copied from [currentStreak].
  const CurrentStreakFamily();

  /// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
  ///
  /// Copied from [currentStreak].
  CurrentStreakProvider call(
    String styleId,
  ) {
    return CurrentStreakProvider(
      styleId,
    );
  }

  @override
  CurrentStreakProvider getProviderOverride(
    covariant CurrentStreakProvider provider,
  ) {
    return call(
      provider.styleId,
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
  String? get name => r'currentStreakProvider';
}

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
///
/// Copied from [currentStreak].
class CurrentStreakProvider extends AutoDisposeProvider<int> {
  /// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
  ///
  /// Copied from [currentStreak].
  CurrentStreakProvider(
    String styleId,
  ) : this._internal(
          (ref) => currentStreak(
            ref as CurrentStreakRef,
            styleId,
          ),
          from: currentStreakProvider,
          name: r'currentStreakProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$currentStreakHash,
          dependencies: CurrentStreakFamily._dependencies,
          allTransitiveDependencies:
              CurrentStreakFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  CurrentStreakProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.styleId,
  }) : super.internal();

  final String styleId;

  @override
  Override overrideWith(
    int Function(CurrentStreakRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CurrentStreakProvider._internal(
        (ref) => create(ref as CurrentStreakRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        styleId: styleId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<int> createElement() {
    return _CurrentStreakProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentStreakProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin CurrentStreakRef on AutoDisposeProviderRef<int> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _CurrentStreakProviderElement extends AutoDisposeProviderElement<int>
    with CurrentStreakRef {
  _CurrentStreakProviderElement(super.provider);

  @override
  String get styleId => (origin as CurrentStreakProvider).styleId;
}

String _$styleDateRangeHash() => r'7b23cb2b263f7a82b0a0d82bc369b8d722260016';

/// 根据 Style 获取该 Style 的日期范围
///
/// Copied from [styleDateRange].
@ProviderFor(styleDateRange)
const styleDateRangeProvider = StyleDateRangeFamily();

/// 根据 Style 获取该 Style 的日期范围
///
/// Copied from [styleDateRange].
class StyleDateRangeFamily extends Family<DateTimeRange?> {
  /// 根据 Style 获取该 Style 的日期范围
  ///
  /// Copied from [styleDateRange].
  const StyleDateRangeFamily();

  /// 根据 Style 获取该 Style 的日期范围
  ///
  /// Copied from [styleDateRange].
  StyleDateRangeProvider call({
    required Style? style,
  }) {
    return StyleDateRangeProvider(
      style: style,
    );
  }

  @override
  StyleDateRangeProvider getProviderOverride(
    covariant StyleDateRangeProvider provider,
  ) {
    return call(
      style: provider.style,
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
  String? get name => r'styleDateRangeProvider';
}

/// 根据 Style 获取该 Style 的日期范围
///
/// Copied from [styleDateRange].
class StyleDateRangeProvider extends AutoDisposeProvider<DateTimeRange?> {
  /// 根据 Style 获取该 Style 的日期范围
  ///
  /// Copied from [styleDateRange].
  StyleDateRangeProvider({
    required Style? style,
  }) : this._internal(
          (ref) => styleDateRange(
            ref as StyleDateRangeRef,
            style: style,
          ),
          from: styleDateRangeProvider,
          name: r'styleDateRangeProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$styleDateRangeHash,
          dependencies: StyleDateRangeFamily._dependencies,
          allTransitiveDependencies:
              StyleDateRangeFamily._allTransitiveDependencies,
          style: style,
        );

  StyleDateRangeProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.style,
  }) : super.internal();

  final Style? style;

  @override
  Override overrideWith(
    DateTimeRange? Function(StyleDateRangeRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StyleDateRangeProvider._internal(
        (ref) => create(ref as StyleDateRangeRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        style: style,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<DateTimeRange?> createElement() {
    return _StyleDateRangeProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StyleDateRangeProvider && other.style == style;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, style.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin StyleDateRangeRef on AutoDisposeProviderRef<DateTimeRange?> {
  /// The parameter `style` of this provider.
  Style? get style;
}

class _StyleDateRangeProviderElement
    extends AutoDisposeProviderElement<DateTimeRange?> with StyleDateRangeRef {
  _StyleDateRangeProviderElement(super.provider);

  @override
  Style? get style => (origin as StyleDateRangeProvider).style;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
