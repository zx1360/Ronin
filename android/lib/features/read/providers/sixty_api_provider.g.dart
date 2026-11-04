// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sixtyApiClientHash() => r'fa7a69974ef86e6dd79cb252ba93ec38b207b824';

/// See also [sixtyApiClient].
@ProviderFor(sixtyApiClient)
final sixtyApiClientProvider = Provider<ApiClient>.internal(
  sixtyApiClient,
  name: r'sixtyApiClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sixtyApiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SixtyApiClientRef = ProviderRef<ApiClient>;
String _$sixtySecondsHash() => r'796bfbcf7f26199999cf52ca72f26f3255940d38';

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

String _$bingWallpaperHash() => r'e4c044665565dd9bbae67ae3b33587b9954944d6';

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
String _$epicGamesHash() => r'a19486752ef172a2505f561f62bd7fda6addc376';

/// See also [epicGames].
@ProviderFor(epicGames)
final epicGamesProvider = AutoDisposeFutureProvider<List<dynamic>>.internal(
  epicGames,
  name: r'epicGamesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$epicGamesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EpicGamesRef = AutoDisposeFutureProviderRef<List<dynamic>>;
String _$toutiaoHotHash() => r'7a2977eb75b673298c51fe11f828660acc979f9c';

/// See also [toutiaoHot].
@ProviderFor(toutiaoHot)
final toutiaoHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  toutiaoHot,
  name: r'toutiaoHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$toutiaoHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ToutiaoHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$zhihuHotHash() => r'1f49875e34269e0d187823c2cfc6aa1cce5ad52d';

/// See also [zhihuHot].
@ProviderFor(zhihuHot)
final zhihuHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  zhihuHot,
  name: r'zhihuHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$zhihuHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ZhihuHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$baiduTiebaHash() => r'2b3d5c5e359d2f671cb6bd34173f384b33bc2dbd';

/// See also [baiduTieba].
@ProviderFor(baiduTieba)
final baiduTiebaProvider = AutoDisposeFutureProvider<dynamic>.internal(
  baiduTieba,
  name: r'baiduTiebaProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$baiduTiebaHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BaiduTiebaRef = AutoDisposeFutureProviderRef<dynamic>;
String _$hitokotoHash() => r'79fe8926c2d4026ec664276b5183b7bf415c451e';

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
String _$duanziHash() => r'ec21984c4fd5fe1c04f0a6a474b943e1132feb53';

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
String _$fabingHash() => r'a6bbd965c85d23070109193effdcfc331505866c';

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

String _$kfcCopyHash() => r'79b8b52759a473725eec45bdb21b57771c8486c5';

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
String _$dadJokeHash() => r'f263a40ae998f6de19878da0f264f5e914ca4cf9';

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
