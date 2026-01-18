// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$labelsHash() => r'a4807c62a23711524f0da9764bfef6308d265b10';

/// 所有标签列表（按随笔数量降序排列）
///
/// Copied from [labels].
@ProviderFor(labels)
final labelsProvider = AutoDisposeProvider<List<Label>>.internal(
  labels,
  name: r'labelsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$labelsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LabelsRef = AutoDisposeProviderRef<List<Label>>;
String _$idMapHash() => r'e9610658a70dc1ad4da555431b922f231b93c8bf';

/// 标签 ID 到名称的映射表
///
/// 便于在显示时快速查找标签名称。
///
/// Copied from [idMap].
@ProviderFor(idMap)
final idMapProvider = AutoDisposeProvider<Map<String, String>>.internal(
  idMap,
  name: r'idMapProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$idMapHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef IdMapRef = AutoDisposeProviderRef<Map<String, String>>;
String _$summariesHash() => r'59992ea03bca0de1ae15ab1c66b342d633756521';

/// 所有年度统计数据（按年份降序排列）
///
/// 每个年度内的月份数据按月份升序排列。
///
/// Copied from [summaries].
@ProviderFor(summaries)
final summariesProvider = AutoDisposeProvider<List<YearSummary>>.internal(
  summaries,
  name: r'summariesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$summariesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SummariesRef = AutoDisposeProviderRef<List<YearSummary>>;
String _$filteredEssaysHash() => r'96fa72df99045c9574dfae767701d7bfcd5dc3b1';

/// 经过筛选和排序的随笔列表
///
/// 根据 [BrowseManager] 的设置进行标签筛选和排序。
///
/// Copied from [filteredEssays].
@ProviderFor(filteredEssays)
final filteredEssaysProvider = AutoDisposeFutureProvider<List<Essay>>.internal(
  filteredEssays,
  name: r'filteredEssaysProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredEssaysHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FilteredEssaysRef = AutoDisposeFutureProviderRef<List<Essay>>;
String _$yearEssaysHash() => r'4ebd558a69783101aaf7f4b346826f0b6f9666c9';

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

/// 指定年份的随笔列表（基于筛选结果）
///
/// Copied from [yearEssays].
@ProviderFor(yearEssays)
const yearEssaysProvider = YearEssaysFamily();

/// 指定年份的随笔列表（基于筛选结果）
///
/// Copied from [yearEssays].
class YearEssaysFamily extends Family<AsyncValue<List<Essay>>> {
  /// 指定年份的随笔列表（基于筛选结果）
  ///
  /// Copied from [yearEssays].
  const YearEssaysFamily();

  /// 指定年份的随笔列表（基于筛选结果）
  ///
  /// Copied from [yearEssays].
  YearEssaysProvider call({
    required String year,
  }) {
    return YearEssaysProvider(
      year: year,
    );
  }

  @override
  YearEssaysProvider getProviderOverride(
    covariant YearEssaysProvider provider,
  ) {
    return call(
      year: provider.year,
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
  String? get name => r'yearEssaysProvider';
}

/// 指定年份的随笔列表（基于筛选结果）
///
/// Copied from [yearEssays].
class YearEssaysProvider extends AutoDisposeFutureProvider<List<Essay>> {
  /// 指定年份的随笔列表（基于筛选结果）
  ///
  /// Copied from [yearEssays].
  YearEssaysProvider({
    required String year,
  }) : this._internal(
          (ref) => yearEssays(
            ref as YearEssaysRef,
            year: year,
          ),
          from: yearEssaysProvider,
          name: r'yearEssaysProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$yearEssaysHash,
          dependencies: YearEssaysFamily._dependencies,
          allTransitiveDependencies:
              YearEssaysFamily._allTransitiveDependencies,
          year: year,
        );

  YearEssaysProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.year,
  }) : super.internal();

  final String year;

  @override
  Override overrideWith(
    FutureOr<List<Essay>> Function(YearEssaysRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: YearEssaysProvider._internal(
        (ref) => create(ref as YearEssaysRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        year: year,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Essay>> createElement() {
    return _YearEssaysProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is YearEssaysProvider && other.year == year;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, year.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin YearEssaysRef on AutoDisposeFutureProviderRef<List<Essay>> {
  /// The parameter `year` of this provider.
  String get year;
}

class _YearEssaysProviderElement
    extends AutoDisposeFutureProviderElement<List<Essay>> with YearEssaysRef {
  _YearEssaysProviderElement(super.provider);

  @override
  String get year => (origin as YearEssaysProvider).year;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
