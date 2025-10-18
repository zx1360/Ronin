// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$essaysHash() => r'8ff79b4e68a3ab673a6645e80fb41cca8e418d7e';

/// See also [essays].
@ProviderFor(essays)
final essaysProvider = AutoDisposeProvider<List<Essay>>.internal(
  essays,
  name: r'essaysProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essaysHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EssaysRef = AutoDisposeProviderRef<List<Essay>>;
String _$labelsHash() => r'a4807c62a23711524f0da9764bfef6308d265b10';

/// See also [labels].
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

/// See also [idMap].
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

/// See also [summaries].
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
String _$filteredEssaysHash() => r'a90bc62557ca51b928d2759581615a098a26da77';

/// See also [filteredEssays].
@ProviderFor(filteredEssays)
final filteredEssaysProvider = AutoDisposeProvider<List<Essay>>.internal(
  filteredEssays,
  name: r'filteredEssaysProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$filteredEssaysHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FilteredEssaysRef = AutoDisposeProviderRef<List<Essay>>;
String _$yearEssaysHash() => r'ee418f185798e1c482777f2407f02b67d8dfa2dd';

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

/// See also [yearEssays].
@ProviderFor(yearEssays)
const yearEssaysProvider = YearEssaysFamily();

/// See also [yearEssays].
class YearEssaysFamily extends Family<List<Essay>> {
  /// See also [yearEssays].
  const YearEssaysFamily();

  /// See also [yearEssays].
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

/// See also [yearEssays].
class YearEssaysProvider extends AutoDisposeProvider<List<Essay>> {
  /// See also [yearEssays].
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
    List<Essay> Function(YearEssaysRef provider) create,
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
  AutoDisposeProviderElement<List<Essay>> createElement() {
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

mixin YearEssaysRef on AutoDisposeProviderRef<List<Essay>> {
  /// The parameter `year` of this provider.
  String get year;
}

class _YearEssaysProviderElement extends AutoDisposeProviderElement<List<Essay>>
    with YearEssaysRef {
  _YearEssaysProviderElement(super.provider);

  @override
  String get year => (origin as YearEssaysProvider).year;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
