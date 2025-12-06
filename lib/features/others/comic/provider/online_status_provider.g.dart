// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicsOnlineHash() => r'2373f660285c8adc033b78b45acec5b324b27d10';

/// See also [comicsOnline].
@ProviderFor(comicsOnline)
final comicsOnlineProvider =
    AutoDisposeFutureProvider<List<ComicInfo>>.internal(
  comicsOnline,
  name: r'comicsOnlineProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicsOnlineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicsOnlineRef = AutoDisposeFutureProviderRef<List<ComicInfo>>;
String _$onlineChaptersWithComicIdHash() =>
    r'3f000f73115aca49a26d987356feaad92d7c3bde';

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

/// See also [onlineChaptersWithComicId].
@ProviderFor(onlineChaptersWithComicId)
const onlineChaptersWithComicIdProvider = OnlineChaptersWithComicIdFamily();

/// See also [onlineChaptersWithComicId].
class OnlineChaptersWithComicIdFamily
    extends Family<AsyncValue<List<ChapterInfo>>> {
  /// See also [onlineChaptersWithComicId].
  const OnlineChaptersWithComicIdFamily();

  /// See also [onlineChaptersWithComicId].
  OnlineChaptersWithComicIdProvider call({
    required String comicId,
  }) {
    return OnlineChaptersWithComicIdProvider(
      comicId: comicId,
    );
  }

  @override
  OnlineChaptersWithComicIdProvider getProviderOverride(
    covariant OnlineChaptersWithComicIdProvider provider,
  ) {
    return call(
      comicId: provider.comicId,
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
  String? get name => r'onlineChaptersWithComicIdProvider';
}

/// See also [onlineChaptersWithComicId].
class OnlineChaptersWithComicIdProvider
    extends AutoDisposeFutureProvider<List<ChapterInfo>> {
  /// See also [onlineChaptersWithComicId].
  OnlineChaptersWithComicIdProvider({
    required String comicId,
  }) : this._internal(
          (ref) => onlineChaptersWithComicId(
            ref as OnlineChaptersWithComicIdRef,
            comicId: comicId,
          ),
          from: onlineChaptersWithComicIdProvider,
          name: r'onlineChaptersWithComicIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$onlineChaptersWithComicIdHash,
          dependencies: OnlineChaptersWithComicIdFamily._dependencies,
          allTransitiveDependencies:
              OnlineChaptersWithComicIdFamily._allTransitiveDependencies,
          comicId: comicId,
        );

  OnlineChaptersWithComicIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.comicId,
  }) : super.internal();

  final String comicId;

  @override
  Override overrideWith(
    FutureOr<List<ChapterInfo>> Function(OnlineChaptersWithComicIdRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OnlineChaptersWithComicIdProvider._internal(
        (ref) => create(ref as OnlineChaptersWithComicIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        comicId: comicId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ChapterInfo>> createElement() {
    return _OnlineChaptersWithComicIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OnlineChaptersWithComicIdProvider &&
        other.comicId == comicId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, comicId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin OnlineChaptersWithComicIdRef
    on AutoDisposeFutureProviderRef<List<ChapterInfo>> {
  /// The parameter `comicId` of this provider.
  String get comicId;
}

class _OnlineChaptersWithComicIdProviderElement
    extends AutoDisposeFutureProviderElement<List<ChapterInfo>>
    with OnlineChaptersWithComicIdRef {
  _OnlineChaptersWithComicIdProviderElement(super.provider);

  @override
  String get comicId => (origin as OnlineChaptersWithComicIdProvider).comicId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
