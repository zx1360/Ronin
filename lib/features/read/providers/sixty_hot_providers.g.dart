// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_hot_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dongchediHotHash() => r'1f238defd5b8c53aa871dd3bb898309713f87a58';

/// See also [dongchediHot].
@ProviderFor(dongchediHot)
final dongchediHotProvider = AutoDisposeFutureProvider<List<dynamic>>.internal(
  dongchediHot,
  name: r'dongchediHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$dongchediHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DongchediHotRef = AutoDisposeFutureProviderRef<List<dynamic>>;
String _$maoyanAllBoxOfficeHash() =>
    r'e7e2967c9a00df1a5063887a684f5021b7395d0f';

/// See also [maoyanAllBoxOffice].
@ProviderFor(maoyanAllBoxOffice)
final maoyanAllBoxOfficeProvider = AutoDisposeFutureProvider<Json>.internal(
  maoyanAllBoxOffice,
  name: r'maoyanAllBoxOfficeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$maoyanAllBoxOfficeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MaoyanAllBoxOfficeRef = AutoDisposeFutureProviderRef<Json>;
String _$maoyanRealtimeMovieHash() =>
    r'4856597232e1b5474f607b396bd1689f5889bda4';

/// See also [maoyanRealtimeMovie].
@ProviderFor(maoyanRealtimeMovie)
final maoyanRealtimeMovieProvider = AutoDisposeFutureProvider<Json>.internal(
  maoyanRealtimeMovie,
  name: r'maoyanRealtimeMovieProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$maoyanRealtimeMovieHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MaoyanRealtimeMovieRef = AutoDisposeFutureProviderRef<Json>;
String _$maoyanRealtimeTvHash() => r'8ff43b1af7dc649c2e92745e085cce9b2b444edc';

/// See also [maoyanRealtimeTv].
@ProviderFor(maoyanRealtimeTv)
final maoyanRealtimeTvProvider = AutoDisposeFutureProvider<Json>.internal(
  maoyanRealtimeTv,
  name: r'maoyanRealtimeTvProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$maoyanRealtimeTvHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MaoyanRealtimeTvRef = AutoDisposeFutureProviderRef<Json>;
String _$maoyanRealtimeWebHash() => r'8fafb8f9e5baef4f962d7e1b0225ed2ee3f86be8';

/// See also [maoyanRealtimeWeb].
@ProviderFor(maoyanRealtimeWeb)
final maoyanRealtimeWebProvider = AutoDisposeFutureProvider<Json>.internal(
  maoyanRealtimeWeb,
  name: r'maoyanRealtimeWebProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$maoyanRealtimeWebHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef MaoyanRealtimeWebRef = AutoDisposeFutureProviderRef<Json>;
String _$toutiaoHotHash() => r'd05f664a4d02137a3d822b3b97441c82c9aec383';

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
String _$weiboHotHash() => r'd12f2d94d042c8507c05b7f4a45e9c2ded31c648';

/// See also [weiboHot].
@ProviderFor(weiboHot)
final weiboHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  weiboHot,
  name: r'weiboHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$weiboHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef WeiboHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$zhihuHotHash() => r'2c1c82888a082d6407c91d4f7e26d0ed6622700c';

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
String _$hackerNewsHash() => r'a4780f529f06b4d2bd37b85bd2388c7d8edee397';

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

/// See also [hackerNews].
@ProviderFor(hackerNews)
const hackerNewsProvider = HackerNewsFamily();

/// See also [hackerNews].
class HackerNewsFamily extends Family<AsyncValue<dynamic>> {
  /// See also [hackerNews].
  const HackerNewsFamily();

  /// See also [hackerNews].
  HackerNewsProvider call(
    String kind,
  ) {
    return HackerNewsProvider(
      kind,
    );
  }

  @override
  HackerNewsProvider getProviderOverride(
    covariant HackerNewsProvider provider,
  ) {
    return call(
      provider.kind,
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
  String? get name => r'hackerNewsProvider';
}

/// See also [hackerNews].
class HackerNewsProvider extends AutoDisposeFutureProvider<dynamic> {
  /// See also [hackerNews].
  HackerNewsProvider(
    String kind,
  ) : this._internal(
          (ref) => hackerNews(
            ref as HackerNewsRef,
            kind,
          ),
          from: hackerNewsProvider,
          name: r'hackerNewsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$hackerNewsHash,
          dependencies: HackerNewsFamily._dependencies,
          allTransitiveDependencies:
              HackerNewsFamily._allTransitiveDependencies,
          kind: kind,
        );

  HackerNewsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.kind,
  }) : super.internal();

  final String kind;

  @override
  Override overrideWith(
    FutureOr<dynamic> Function(HackerNewsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: HackerNewsProvider._internal(
        (ref) => create(ref as HackerNewsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        kind: kind,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<dynamic> createElement() {
    return _HackerNewsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is HackerNewsProvider && other.kind == kind;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, kind.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin HackerNewsRef on AutoDisposeFutureProviderRef<dynamic> {
  /// The parameter `kind` of this provider.
  String get kind;
}

class _HackerNewsProviderElement
    extends AutoDisposeFutureProviderElement<dynamic> with HackerNewsRef {
  _HackerNewsProviderElement(super.provider);

  @override
  String get kind => (origin as HackerNewsProvider).kind;
}

String _$baiduHotHash() => r'455ebc74f7bf9b9401ed189b23d4d3309313641d';

/// See also [baiduHot].
@ProviderFor(baiduHot)
final baiduHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  baiduHot,
  name: r'baiduHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$baiduHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BaiduHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$baiduTeleplayHash() => r'66007959bf7469c7528bb69813e20a088b0bb6fc';

/// See also [baiduTeleplay].
@ProviderFor(baiduTeleplay)
final baiduTeleplayProvider = AutoDisposeFutureProvider<dynamic>.internal(
  baiduTeleplay,
  name: r'baiduTeleplayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$baiduTeleplayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BaiduTeleplayRef = AutoDisposeFutureProviderRef<dynamic>;
String _$baiduTiebaHash() => r'a51fe8699db1e16ea88fe39696c4cfb63fe44c9b';

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
String _$ncmRankListHash() => r'754f7b678b41dba7af637f9989756c524ea674ed';

/// See also [ncmRankList].
@ProviderFor(ncmRankList)
final ncmRankListProvider = AutoDisposeFutureProvider<dynamic>.internal(
  ncmRankList,
  name: r'ncmRankListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$ncmRankListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NcmRankListRef = AutoDisposeFutureProviderRef<dynamic>;
String _$biliHotHash() => r'edddb62abdc99b4a7c21b8536e27f1f7e832c4d1';

/// See also [biliHot].
@ProviderFor(biliHot)
final biliHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  biliHot,
  name: r'biliHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$biliHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BiliHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$douyinHotHash() => r'8970707b7c39911e8166070f61efbdc7f486623a';

/// See also [douyinHot].
@ProviderFor(douyinHot)
final douyinHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  douyinHot,
  name: r'douyinHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$douyinHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DouyinHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$quarkHotHash() => r'73f880d021002e149314cccf4767d2966e1a2e23';

/// See also [quarkHot].
@ProviderFor(quarkHot)
final quarkHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  quarkHot,
  name: r'quarkHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$quarkHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef QuarkHotRef = AutoDisposeFutureProviderRef<dynamic>;
String _$rednoteHotHash() => r'5cdb339ed60cc12c948eb2d3bc1fb008986c801d';

/// See also [rednoteHot].
@ProviderFor(rednoteHot)
final rednoteHotProvider = AutoDisposeFutureProvider<dynamic>.internal(
  rednoteHot,
  name: r'rednoteHotProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$rednoteHotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RednoteHotRef = AutoDisposeFutureProviderRef<dynamic>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
