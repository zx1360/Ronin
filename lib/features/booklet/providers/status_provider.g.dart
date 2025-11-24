// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stylesHash() => r'9b9c875963eb2edcb01413700bce6a873421d681';

/// See also [styles].
@ProviderFor(styles)
final stylesProvider = AutoDisposeProvider<List<Style>>.internal(
  styles,
  name: r'stylesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$stylesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StylesRef = AutoDisposeProviderRef<List<Style>>;
String _$recordsHash() => r'3b4cb3e3f61374fb40e011172745974b2270b2b6';

/// See also [records].
@ProviderFor(records)
final recordsProvider = AutoDisposeProvider<List<Record>>.internal(
  records,
  name: r'recordsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$recordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecordsRef = AutoDisposeProviderRef<List<Record>>;
String _$styleWithIdHash() => r'0cf8b225a59b16c1ef853d0875aacc4c4252005f';

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

/// See also [styleWithId].
@ProviderFor(styleWithId)
const styleWithIdProvider = StyleWithIdFamily();

/// See also [styleWithId].
class StyleWithIdFamily extends Family<Style?> {
  /// See also [styleWithId].
  const StyleWithIdFamily();

  /// See also [styleWithId].
  StyleWithIdProvider call(
    String styleId,
  ) {
    return StyleWithIdProvider(
      styleId,
    );
  }

  @override
  StyleWithIdProvider getProviderOverride(
    covariant StyleWithIdProvider provider,
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
  String? get name => r'styleWithIdProvider';
}

/// See also [styleWithId].
class StyleWithIdProvider extends AutoDisposeProvider<Style?> {
  /// See also [styleWithId].
  StyleWithIdProvider(
    String styleId,
  ) : this._internal(
          (ref) => styleWithId(
            ref as StyleWithIdRef,
            styleId,
          ),
          from: styleWithIdProvider,
          name: r'styleWithIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$styleWithIdHash,
          dependencies: StyleWithIdFamily._dependencies,
          allTransitiveDependencies:
              StyleWithIdFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  StyleWithIdProvider._internal(
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
    Style? Function(StyleWithIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StyleWithIdProvider._internal(
        (ref) => create(ref as StyleWithIdRef),
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
  AutoDisposeProviderElement<Style?> createElement() {
    return _StyleWithIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StyleWithIdProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin StyleWithIdRef on AutoDisposeProviderRef<Style?> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _StyleWithIdProviderElement extends AutoDisposeProviderElement<Style?>
    with StyleWithIdRef {
  _StyleWithIdProviderElement(super.provider);

  @override
  String get styleId => (origin as StyleWithIdProvider).styleId;
}

String _$latestStyleHash() => r'b3562555ba2b06292d86b920f5c0a4b91d389de9';

/// See also [latestStyle].
@ProviderFor(latestStyle)
final latestStyleProvider = AutoDisposeProvider<Style?>.internal(
  latestStyle,
  name: r'latestStyleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$latestStyleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LatestStyleRef = AutoDisposeProviderRef<Style?>;
String _$styleDateRangeHash() => r'e79978ad6238cf04b40a4fa0ee91ef0539667500';

/// See also [styleDateRange].
@ProviderFor(styleDateRange)
const styleDateRangeProvider = StyleDateRangeFamily();

/// See also [styleDateRange].
class StyleDateRangeFamily extends Family<DateTimeRange?> {
  /// See also [styleDateRange].
  const StyleDateRangeFamily();

  /// See also [styleDateRange].
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

/// See also [styleDateRange].
class StyleDateRangeProvider extends AutoDisposeProvider<DateTimeRange?> {
  /// See also [styleDateRange].
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

String _$todayRecordHash() => r'4e5a35a1336f2845b535df1b32a6cd83f054fe65';

/// See also [todayRecord].
@ProviderFor(todayRecord)
final todayRecordProvider = AutoDisposeProvider<Record?>.internal(
  todayRecord,
  name: r'todayRecordProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$todayRecordHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TodayRecordRef = AutoDisposeProviderRef<Record?>;
String _$recordWithDateHash() => r'6dcd7517241a3da2cf47677c3b2e0fc1fa23d694';

/// See also [recordWithDate].
@ProviderFor(recordWithDate)
const recordWithDateProvider = RecordWithDateFamily();

/// See also [recordWithDate].
class RecordWithDateFamily extends Family<Record?> {
  /// See also [recordWithDate].
  const RecordWithDateFamily();

  /// See also [recordWithDate].
  RecordWithDateProvider call({
    required DateTime targetDate,
  }) {
    return RecordWithDateProvider(
      targetDate: targetDate,
    );
  }

  @override
  RecordWithDateProvider getProviderOverride(
    covariant RecordWithDateProvider provider,
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
  String? get name => r'recordWithDateProvider';
}

/// See also [recordWithDate].
class RecordWithDateProvider extends AutoDisposeProvider<Record?> {
  /// See also [recordWithDate].
  RecordWithDateProvider({
    required DateTime targetDate,
  }) : this._internal(
          (ref) => recordWithDate(
            ref as RecordWithDateRef,
            targetDate: targetDate,
          ),
          from: recordWithDateProvider,
          name: r'recordWithDateProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$recordWithDateHash,
          dependencies: RecordWithDateFamily._dependencies,
          allTransitiveDependencies:
              RecordWithDateFamily._allTransitiveDependencies,
          targetDate: targetDate,
        );

  RecordWithDateProvider._internal(
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
    Record? Function(RecordWithDateRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecordWithDateProvider._internal(
        (ref) => create(ref as RecordWithDateRef),
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
    return _RecordWithDateProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordWithDateProvider && other.targetDate == targetDate;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetDate.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RecordWithDateRef on AutoDisposeProviderRef<Record?> {
  /// The parameter `targetDate` of this provider.
  DateTime get targetDate;
}

class _RecordWithDateProviderElement extends AutoDisposeProviderElement<Record?>
    with RecordWithDateRef {
  _RecordWithDateProviderElement(super.provider);

  @override
  DateTime get targetDate => (origin as RecordWithDateProvider).targetDate;
}

String _$recordsWithStyleidHash() =>
    r'4818c44e7053a48f7615500c0b263c52521af0c5';

/// See also [recordsWithStyleid].
@ProviderFor(recordsWithStyleid)
const recordsWithStyleidProvider = RecordsWithStyleidFamily();

/// See also [recordsWithStyleid].
class RecordsWithStyleidFamily extends Family<List<Record>> {
  /// See also [recordsWithStyleid].
  const RecordsWithStyleidFamily();

  /// See also [recordsWithStyleid].
  RecordsWithStyleidProvider call(
    String styleId,
  ) {
    return RecordsWithStyleidProvider(
      styleId,
    );
  }

  @override
  RecordsWithStyleidProvider getProviderOverride(
    covariant RecordsWithStyleidProvider provider,
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
  String? get name => r'recordsWithStyleidProvider';
}

/// See also [recordsWithStyleid].
class RecordsWithStyleidProvider extends AutoDisposeProvider<List<Record>> {
  /// See also [recordsWithStyleid].
  RecordsWithStyleidProvider(
    String styleId,
  ) : this._internal(
          (ref) => recordsWithStyleid(
            ref as RecordsWithStyleidRef,
            styleId,
          ),
          from: recordsWithStyleidProvider,
          name: r'recordsWithStyleidProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$recordsWithStyleidHash,
          dependencies: RecordsWithStyleidFamily._dependencies,
          allTransitiveDependencies:
              RecordsWithStyleidFamily._allTransitiveDependencies,
          styleId: styleId,
        );

  RecordsWithStyleidProvider._internal(
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
    List<Record> Function(RecordsWithStyleidRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: RecordsWithStyleidProvider._internal(
        (ref) => create(ref as RecordsWithStyleidRef),
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
    return _RecordsWithStyleidProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RecordsWithStyleidProvider && other.styleId == styleId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, styleId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin RecordsWithStyleidRef on AutoDisposeProviderRef<List<Record>> {
  /// The parameter `styleId` of this provider.
  String get styleId;
}

class _RecordsWithStyleidProviderElement
    extends AutoDisposeProviderElement<List<Record>>
    with RecordsWithStyleidRef {
  _RecordsWithStyleidProviderElement(super.provider);

  @override
  String get styleId => (origin as RecordsWithStyleidProvider).styleId;
}

String _$currentStreakHash() => r'c64934a5453216d25a6a068c4792e4f771010a57';

/// 如果今天有记录，则包含今天
/// 如果今天没有记录，则计算截至昨天的连续天数
/// 如果今天和昨天都没有记录，则返回0
///
/// Copied from [currentStreak].
@ProviderFor(currentStreak)
const currentStreakProvider = CurrentStreakFamily();

/// 如果今天有记录，则包含今天
/// 如果今天没有记录，则计算截至昨天的连续天数
/// 如果今天和昨天都没有记录，则返回0
///
/// Copied from [currentStreak].
class CurrentStreakFamily extends Family<int> {
  /// 如果今天有记录，则包含今天
  /// 如果今天没有记录，则计算截至昨天的连续天数
  /// 如果今天和昨天都没有记录，则返回0
  ///
  /// Copied from [currentStreak].
  const CurrentStreakFamily();

  /// 如果今天有记录，则包含今天
  /// 如果今天没有记录，则计算截至昨天的连续天数
  /// 如果今天和昨天都没有记录，则返回0
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

/// 如果今天有记录，则包含今天
/// 如果今天没有记录，则计算截至昨天的连续天数
/// 如果今天和昨天都没有记录，则返回0
///
/// Copied from [currentStreak].
class CurrentStreakProvider extends AutoDisposeProvider<int> {
  /// 如果今天有记录，则包含今天
  /// 如果今天没有记录，则计算截至昨天的连续天数
  /// 如果今天和昨天都没有记录，则返回0
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

String _$jsonDataHash() => r'39dc683074dc7901f200f3c56aec472ed9baaa71';

/// See also [jsonData].
@ProviderFor(jsonData)
final jsonDataProvider = AutoDisposeProvider<Map<String, dynamic>>.internal(
  jsonData,
  name: r'jsonDataProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$jsonDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef JsonDataRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$imgPathsHash() => r'becbbf91c02a945b15ac3196839fa1b1b27e802a';

/// See also [imgPaths].
@ProviderFor(imgPaths)
final imgPathsProvider = AutoDisposeProvider<List<String>>.internal(
  imgPaths,
  name: r'imgPathsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$imgPathsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ImgPathsRef = AutoDisposeProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
