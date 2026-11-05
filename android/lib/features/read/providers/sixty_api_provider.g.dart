// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sixtyApiClientHash() => r'f7dd53caa9a33c1f6c9d7348bf1e1c10fb6adbcc';

/// See also [sixtyApiClient].
@ProviderFor(sixtyApiClient)
final sixtyApiClientProvider = Provider<SixtyApiClient>.internal(
  sixtyApiClient,
  name: r'sixtyApiClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sixtyApiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SixtyApiClientRef = ProviderRef<SixtyApiClient>;
String _$sixtySecondsHash() => r'c9f07eda36aba644ab87bdc0b106d586814369f1';

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

/// See also [sixtySeconds].
@ProviderFor(sixtySeconds)
const sixtySecondsProvider = SixtySecondsFamily();

/// See also [sixtySeconds].
class SixtySecondsFamily extends Family<AsyncValue<Json>> {
  /// See also [sixtySeconds].
  const SixtySecondsFamily();

  /// See also [sixtySeconds].
  SixtySecondsProvider call(
    String? date,
  ) {
    return SixtySecondsProvider(
      date,
    );
  }

  @override
  SixtySecondsProvider getProviderOverride(
    covariant SixtySecondsProvider provider,
  ) {
    return call(
      provider.date,
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
  String? get name => r'sixtySecondsProvider';
}

/// See also [sixtySeconds].
class SixtySecondsProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [sixtySeconds].
  SixtySecondsProvider(
    String? date,
  ) : this._internal(
          (ref) => sixtySeconds(
            ref as SixtySecondsRef,
            date,
          ),
          from: sixtySecondsProvider,
          name: r'sixtySecondsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$sixtySecondsHash,
          dependencies: SixtySecondsFamily._dependencies,
          allTransitiveDependencies:
              SixtySecondsFamily._allTransitiveDependencies,
          date: date,
        );

  SixtySecondsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.date,
  }) : super.internal();

  final String? date;

  @override
  Override overrideWith(
    FutureOr<Json> Function(SixtySecondsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SixtySecondsProvider._internal(
        (ref) => create(ref as SixtySecondsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Json> createElement() {
    return _SixtySecondsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SixtySecondsProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SixtySecondsRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `date` of this provider.
  String? get date;
}

class _SixtySecondsProviderElement
    extends AutoDisposeFutureProviderElement<Json> with SixtySecondsRef {
  _SixtySecondsProviderElement(super.provider);

  @override
  String? get date => (origin as SixtySecondsProvider).date;
}

String _$bingWallpaperHash() => r'a97d0eba14415349ac3fc98f9b5f294f2a6d3382';

/// See also [bingWallpaper].
@ProviderFor(bingWallpaper)
final bingWallpaperProvider = AutoDisposeFutureProvider<Json>.internal(
  bingWallpaper,
  name: r'bingWallpaperProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bingWallpaperHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BingWallpaperRef = AutoDisposeFutureProviderRef<Json>;
String _$epicGamesHash() => r'e07df46c3255b97f51d59a2fb5b391e0979b065f';

/// See also [epicGames].
@ProviderFor(epicGames)
final epicGamesProvider = AutoDisposeFutureProvider<List<Json>>.internal(
  epicGames,
  name: r'epicGamesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$epicGamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EpicGamesRef = AutoDisposeFutureProviderRef<List<Json>>;
String _$toutiaoHotHash() => r'eb9c422c3fe4d8892bebc0abb2364d9d9d7b3495';

/// See also [toutiaoHot].
@ProviderFor(toutiaoHot)
final toutiaoHotProvider = AutoDisposeFutureProvider<List<Json>>.internal(
  toutiaoHot,
  name: r'toutiaoHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$toutiaoHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ToutiaoHotRef = AutoDisposeFutureProviderRef<List<Json>>;
String _$zhihuHotHash() => r'9e4814de36d80398a63a7eede1c4889cfa880dbe';

/// See also [zhihuHot].
@ProviderFor(zhihuHot)
final zhihuHotProvider = AutoDisposeFutureProvider<List<Json>>.internal(
  zhihuHot,
  name: r'zhihuHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$zhihuHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ZhihuHotRef = AutoDisposeFutureProviderRef<List<Json>>;
String _$baiduTiebaHash() => r'38ba8935966c3058663406b2c0695218c7a437b5';

/// See also [baiduTieba].
@ProviderFor(baiduTieba)
final baiduTiebaProvider = AutoDisposeFutureProvider<List<Json>>.internal(
  baiduTieba,
  name: r'baiduTiebaProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$baiduTiebaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BaiduTiebaRef = AutoDisposeFutureProviderRef<List<Json>>;
String _$hitokotoHash() => r'13052ce8cd700eaa68279ae97d6a0dc4f2bd01ea';

/// See also [hitokoto].
@ProviderFor(hitokoto)
final hitokotoProvider = AutoDisposeFutureProvider<String>.internal(
  hitokoto,
  name: r'hitokotoProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$hitokotoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef HitokotoRef = AutoDisposeFutureProviderRef<String>;
String _$duanziHash() => r'65f6029fc0871cb3753521a439a77b743eee213e';

/// See also [duanzi].
@ProviderFor(duanzi)
final duanziProvider = AutoDisposeFutureProvider<String>.internal(
  duanzi,
  name: r'duanziProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$duanziHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DuanziRef = AutoDisposeFutureProviderRef<String>;
String _$fabingHash() => r'ebd5b102576648e24b88a8b00f86ead8ed9bca59';

/// See also [fabing].
@ProviderFor(fabing)
const fabingProvider = FabingFamily();

/// See also [fabing].
class FabingFamily extends Family<AsyncValue<String>> {
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
class FabingProvider extends AutoDisposeFutureProvider<String> {
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
    FutureOr<String> Function(FabingRef provider) create,
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
  AutoDisposeFutureProviderElement<String> createElement() {
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

mixin FabingRef on AutoDisposeFutureProviderRef<String> {
  /// The parameter `person` of this provider.
  String? get person;
}

class _FabingProviderElement extends AutoDisposeFutureProviderElement<String>
    with FabingRef {
  _FabingProviderElement(super.provider);

  @override
  String? get person => (origin as FabingProvider).person;
}

String _$kfcCopyHash() => r'170b21f04d2df7e954a8ee09e45b97cd9250d3b6';

/// See also [kfcCopy].
@ProviderFor(kfcCopy)
final kfcCopyProvider = AutoDisposeFutureProvider<String>.internal(
  kfcCopy,
  name: r'kfcCopyProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$kfcCopyHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef KfcCopyRef = AutoDisposeFutureProviderRef<String>;
String _$dadJokeHash() => r'11ccf8c6ef3a91b91d64e588a2096f033274f2cf';

/// See also [dadJoke].
@ProviderFor(dadJoke)
final dadJokeProvider = AutoDisposeFutureProvider<String>.internal(
  dadJoke,
  name: r'dadJokeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dadJokeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DadJokeRef = AutoDisposeFutureProviderRef<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
