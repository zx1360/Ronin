// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sixty_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sixtyApiClient)
final sixtyApiClientProvider = SixtyApiClientProvider._();

final class SixtyApiClientProvider
    extends $FunctionalProvider<SixtyApiClient, SixtyApiClient, SixtyApiClient>
    with $Provider<SixtyApiClient> {
  SixtyApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sixtyApiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sixtyApiClientHash();

  @$internal
  @override
  $ProviderElement<SixtyApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SixtyApiClient create(Ref ref) {
    return sixtyApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SixtyApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SixtyApiClient>(value),
    );
  }
}

String _$sixtyApiClientHash() => r'2ea24875f825ec3526d56fd3577c0e132b6a7bb8';

@ProviderFor(sixtySeconds)
final sixtySecondsProvider = SixtySecondsFamily._();

final class SixtySecondsProvider
    extends $FunctionalProvider<AsyncValue<Json>, Json, FutureOr<Json>>
    with $FutureModifier<Json>, $FutureProvider<Json> {
  SixtySecondsProvider._({
    required SixtySecondsFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'sixtySecondsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sixtySecondsHash();

  @override
  String toString() {
    return r'sixtySecondsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Json> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Json> create(Ref ref) {
    final argument = this.argument as String?;
    return sixtySeconds(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SixtySecondsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sixtySecondsHash() => r'a86ad6c79b0998d0d8eec8781a6330b5bf3c1e65';

final class SixtySecondsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Json>, String?> {
  SixtySecondsFamily._()
    : super(
        retry: null,
        name: r'sixtySecondsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SixtySecondsProvider call(String? date) =>
      SixtySecondsProvider._(argument: date, from: this);

  @override
  String toString() => r'sixtySecondsProvider';
}

@ProviderFor(bingWallpaper)
final bingWallpaperProvider = BingWallpaperProvider._();

final class BingWallpaperProvider
    extends $FunctionalProvider<AsyncValue<Json>, Json, FutureOr<Json>>
    with $FutureModifier<Json>, $FutureProvider<Json> {
  BingWallpaperProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bingWallpaperProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bingWallpaperHash();

  @$internal
  @override
  $FutureProviderElement<Json> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Json> create(Ref ref) {
    return bingWallpaper(ref);
  }
}

String _$bingWallpaperHash() => r'7ef9a1fda39c941792a880c0e91cec6c7c64d7f8';

@ProviderFor(epicGames)
final epicGamesProvider = EpicGamesProvider._();

final class EpicGamesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Json>>,
          List<Json>,
          FutureOr<List<Json>>
        >
    with $FutureModifier<List<Json>>, $FutureProvider<List<Json>> {
  EpicGamesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'epicGamesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$epicGamesHash();

  @$internal
  @override
  $FutureProviderElement<List<Json>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Json>> create(Ref ref) {
    return epicGames(ref);
  }
}

String _$epicGamesHash() => r'1fe7b8df7204b59f5e7e43b53fef153933d16293';

@ProviderFor(toutiaoHot)
final toutiaoHotProvider = ToutiaoHotProvider._();

final class ToutiaoHotProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Json>>,
          List<Json>,
          FutureOr<List<Json>>
        >
    with $FutureModifier<List<Json>>, $FutureProvider<List<Json>> {
  ToutiaoHotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'toutiaoHotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$toutiaoHotHash();

  @$internal
  @override
  $FutureProviderElement<List<Json>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Json>> create(Ref ref) {
    return toutiaoHot(ref);
  }
}

String _$toutiaoHotHash() => r'152e619585ea1d28bbfe81ee8a611e88be215bd3';

@ProviderFor(zhihuHot)
final zhihuHotProvider = ZhihuHotProvider._();

final class ZhihuHotProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Json>>,
          List<Json>,
          FutureOr<List<Json>>
        >
    with $FutureModifier<List<Json>>, $FutureProvider<List<Json>> {
  ZhihuHotProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zhihuHotProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zhihuHotHash();

  @$internal
  @override
  $FutureProviderElement<List<Json>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Json>> create(Ref ref) {
    return zhihuHot(ref);
  }
}

String _$zhihuHotHash() => r'e8a2695ccddd256a5fc34fd8a6b18f5d005c2dd1';

@ProviderFor(baiduTieba)
final baiduTiebaProvider = BaiduTiebaProvider._();

final class BaiduTiebaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Json>>,
          List<Json>,
          FutureOr<List<Json>>
        >
    with $FutureModifier<List<Json>>, $FutureProvider<List<Json>> {
  BaiduTiebaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'baiduTiebaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$baiduTiebaHash();

  @$internal
  @override
  $FutureProviderElement<List<Json>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Json>> create(Ref ref) {
    return baiduTieba(ref);
  }
}

String _$baiduTiebaHash() => r'9753d1da2892477e4d52c888f74d70a1a443725d';

@ProviderFor(hitokoto)
final hitokotoProvider = HitokotoProvider._();

final class HitokotoProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  HitokotoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hitokotoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hitokotoHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return hitokoto(ref);
  }
}

String _$hitokotoHash() => r'4209aca7374a7150ae6f2f8bb7a92602a7b0bda3';

@ProviderFor(duanzi)
final duanziProvider = DuanziProvider._();

final class DuanziProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  DuanziProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'duanziProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$duanziHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return duanzi(ref);
  }
}

String _$duanziHash() => r'ad067946995cd59936cacbb81e7d6c385ab3bfcd';

@ProviderFor(fabing)
final fabingProvider = FabingFamily._();

final class FabingProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  FabingProvider._({
    required FabingFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'fabingProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fabingHash();

  @override
  String toString() {
    return r'fabingProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String?;
    return fabing(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FabingProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fabingHash() => r'f775d7193f2623140020ff5d62e63694bd6f1874';

final class FabingFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String?> {
  FabingFamily._()
    : super(
        retry: null,
        name: r'fabingProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FabingProvider call(String? person) =>
      FabingProvider._(argument: person, from: this);

  @override
  String toString() => r'fabingProvider';
}

@ProviderFor(kfcCopy)
final kfcCopyProvider = KfcCopyProvider._();

final class KfcCopyProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  KfcCopyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'kfcCopyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$kfcCopyHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return kfcCopy(ref);
  }
}

String _$kfcCopyHash() => r'e7d092b2351dc6634ce19f253b2232f9d482dcfe';

@ProviderFor(dadJoke)
final dadJokeProvider = DadJokeProvider._();

final class DadJokeProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  DadJokeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dadJokeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dadJokeHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return dadJoke(ref);
  }
}

String _$dadJokeHash() => r'08819a557bf2a8b1e926cf9e9e0f8173c7bf05fc';
