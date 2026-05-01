// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_entertainment_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$changyaAudioHash() => r'9093076a476878ce56fc993ad5a6e5b12af5c7c0';

/// See also [changyaAudio].
@ProviderFor(changyaAudio)
final changyaAudioProvider = AutoDisposeFutureProvider<Json>.internal(
  changyaAudio,
  name: r'changyaAudioProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$changyaAudioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ChangyaAudioRef = AutoDisposeFutureProviderRef<Json>;
String _$hitokotoHash() => r'5c513b0d798227ba57bc9daa2c38dda56f3606ca';

/// See also [hitokoto].
@ProviderFor(hitokoto)
final hitokotoProvider = AutoDisposeFutureProvider<Json>.internal(
  hitokoto,
  name: r'hitokotoProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$hitokotoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HitokotoRef = AutoDisposeFutureProviderRef<Json>;
String _$duanziHash() => r'dcd0d15a25d97d4cba52d077ff8d57d73c889845';

/// See also [duanzi].
@ProviderFor(duanzi)
final duanziProvider = AutoDisposeFutureProvider<Json>.internal(
  duanzi,
  name: r'duanziProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$duanziHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DuanziRef = AutoDisposeFutureProviderRef<Json>;
String _$fabingHash() => r'e406578153991c21fc6c327bc454daca398e27f6';

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

/// See also [fabing].
@ProviderFor(fabing)
const fabingProvider = FabingFamily();

/// See also [fabing].
class FabingFamily extends Family<AsyncValue<Json>> {
  /// See also [fabing].
  const FabingFamily();

  /// See also [fabing].
  FabingProvider call(
    String? person,
  ) {
    return FabingProvider(
      person,
    );
  }

  @override
  FabingProvider getProviderOverride(
    covariant FabingProvider provider,
  ) {
    return call(
      provider.person,
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
  String? get name => r'fabingProvider';
}

/// See also [fabing].
class FabingProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [fabing].
  FabingProvider(
    String? person,
  ) : this._internal(
          (ref) => fabing(
            ref as FabingRef,
            person,
          ),
          from: fabingProvider,
          name: r'fabingProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$fabingHash,
          dependencies: FabingFamily._dependencies,
          allTransitiveDependencies: FabingFamily._allTransitiveDependencies,
          person: person,
        );

  FabingProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.person,
  }) : super.internal();

  final String? person;

  @override
  Override overrideWith(
    FutureOr<Json> Function(FabingRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: FabingProvider._internal(
        (ref) => create(ref as FabingRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        person: person,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Json> createElement() {
    return _FabingProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FabingProvider && other.person == person;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, person.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin FabingRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `person` of this provider.
  String? get person;
}

class _FabingProviderElement extends AutoDisposeFutureProviderElement<Json>
    with FabingRef {
  _FabingProviderElement(super.provider);

  @override
  String? get person => (origin as FabingProvider).person;
}

String _$kfcCopyHash() => r'72093984bf902048aa31eba670ca77ae08d0273a';

/// See also [kfcCopy].
@ProviderFor(kfcCopy)
final kfcCopyProvider = AutoDisposeFutureProvider<Json>.internal(
  kfcCopy,
  name: r'kfcCopyProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$kfcCopyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef KfcCopyRef = AutoDisposeFutureProviderRef<Json>;
String _$dadJokeHash() => r'14ee8514382359bbe7c82d0ec3c40d93373da6bf';

/// See also [dadJoke].
@ProviderFor(dadJoke)
final dadJokeProvider = AutoDisposeFutureProvider<Json>.internal(
  dadJoke,
  name: r'dadJokeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dadJokeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DadJokeRef = AutoDisposeFutureProviderRef<Json>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
