// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_news_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sixtySecondsHash() => r'b1251df5d2b73ad4932d358d98515181da80a619';

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

String _$aiNewsHash() => r'cd56996498da8afd0cc93735b03270d7d2c5b24b';

/// See also [aiNews].
@ProviderFor(aiNews)
const aiNewsProvider = AiNewsFamily();

/// See also [aiNews].
class AiNewsFamily extends Family<AsyncValue<Json>> {
  /// See also [aiNews].
  const AiNewsFamily();

  /// See also [aiNews].
  AiNewsProvider call(
    String? date,
  ) {
    return AiNewsProvider(
      date,
    );
  }

  @override
  AiNewsProvider getProviderOverride(
    covariant AiNewsProvider provider,
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
  String? get name => r'aiNewsProvider';
}

/// See also [aiNews].
class AiNewsProvider extends AutoDisposeFutureProvider<Json> {
  /// See also [aiNews].
  AiNewsProvider(
    String? date,
  ) : this._internal(
          (ref) => aiNews(
            ref as AiNewsRef,
            date,
          ),
          from: aiNewsProvider,
          name: r'aiNewsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$aiNewsHash,
          dependencies: AiNewsFamily._dependencies,
          allTransitiveDependencies: AiNewsFamily._allTransitiveDependencies,
          date: date,
        );

  AiNewsProvider._internal(
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
    FutureOr<Json> Function(AiNewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: AiNewsProvider._internal(
        (ref) => create(ref as AiNewsRef),
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
    return _AiNewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is AiNewsProvider && other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin AiNewsRef on AutoDisposeFutureProviderRef<Json> {
  /// The parameter `date` of this provider.
  String? get date;
}

class _AiNewsProviderElement extends AutoDisposeFutureProviderElement<Json>
    with AiNewsRef {
  _AiNewsProviderElement(super.provider);

  @override
  String? get date => (origin as AiNewsProvider).date;
}

String _$bingWallpaperHash() => r'fb6e59797db5c223a4de22d2d687db546dcdb4d7';

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
String _$epicGamesHash() => r'a4eee16bdf86cb720ed6f489e58173ce6127cd9f';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
