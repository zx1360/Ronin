// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$summaryBoxHash() => r'43b7f357b01ac8e090c1b3c0e7b38be52fcb2796';

/// 年度统计信息的 Hive Box
///
/// Copied from [summaryBox].
@ProviderFor(summaryBox)
final summaryBoxProvider = AutoDisposeProvider<Box<YearSummary>>.internal(
  summaryBox,
  name: r'summaryBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$summaryBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SummaryBoxRef = AutoDisposeProviderRef<Box<YearSummary>>;
String _$essayBoxHash() => r'4c04d29c307c031ea1b3063d5c519218a95d9136';

/// 随笔数据的 Hive Box
///
/// Copied from [essayBox].
@ProviderFor(essayBox)
final essayBoxProvider = AutoDisposeProvider<Box<Essay>>.internal(
  essayBox,
  name: r'essayBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EssayBoxRef = AutoDisposeProviderRef<Box<Essay>>;
String _$essayByIdHash() => r'02794d642db17ff9ddc5a1d8334b40a4542ba20c';

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

/// See also [essayById].
@ProviderFor(essayById)
const essayByIdProvider = EssayByIdFamily();

/// See also [essayById].
class EssayByIdFamily extends Family<AsyncValue<Essay?>> {
  /// See also [essayById].
  const EssayByIdFamily();

  /// See also [essayById].
  EssayByIdProvider call(
    String id,
  ) {
    return EssayByIdProvider(
      id,
    );
  }

  @override
  EssayByIdProvider getProviderOverride(
    covariant EssayByIdProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'essayByIdProvider';
}

/// See also [essayById].
class EssayByIdProvider extends AutoDisposeStreamProvider<Essay?> {
  /// See also [essayById].
  EssayByIdProvider(
    String id,
  ) : this._internal(
          (ref) => essayById(
            ref as EssayByIdRef,
            id,
          ),
          from: essayByIdProvider,
          name: r'essayByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$essayByIdHash,
          dependencies: EssayByIdFamily._dependencies,
          allTransitiveDependencies: EssayByIdFamily._allTransitiveDependencies,
          id: id,
        );

  EssayByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    Stream<Essay?> Function(EssayByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: EssayByIdProvider._internal(
        (ref) => create(ref as EssayByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Essay?> createElement() {
    return _EssayByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EssayByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin EssayByIdRef on AutoDisposeStreamProviderRef<Essay?> {
  /// The parameter `id` of this provider.
  String get id;
}

class _EssayByIdProviderElement extends AutoDisposeStreamProviderElement<Essay?>
    with EssayByIdRef {
  _EssayByIdProviderElement(super.provider);

  @override
  String get id => (origin as EssayByIdProvider).id;
}

String _$essayStreamHash() => r'f3ec87b2c434c806c378da17b5fd9dceb4b6631e';

/// 随笔数据的响应式流
///
/// Copied from [essayStream].
@ProviderFor(essayStream)
final essayStreamProvider = AutoDisposeStreamProvider<List<Essay>>.internal(
  essayStream,
  name: r'essayStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EssayStreamRef = AutoDisposeStreamProviderRef<List<Essay>>;
String _$labelBoxHash() => r'9344185ac11e932f41f54c4341dd772cdf14aa06';

/// 标签数据的 Hive Box
///
/// Copied from [labelBox].
@ProviderFor(labelBox)
final labelBoxProvider = AutoDisposeProvider<Box<Label>>.internal(
  labelBox,
  name: r'labelBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$labelBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LabelBoxRef = AutoDisposeProviderRef<Box<Label>>;
String _$labelStreamHash() => r'08feaadbca6daacf039c17048c856f1e4b0b4499';

/// 标签数据的响应式流
///
/// Copied from [labelStream].
@ProviderFor(labelStream)
final labelStreamProvider = AutoDisposeStreamProvider<List<Label>>.internal(
  labelStream,
  name: r'labelStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$labelStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LabelStreamRef = AutoDisposeStreamProviderRef<List<Label>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
