// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ComicService)
final comicServiceProvider = ComicServiceProvider._();

final class ComicServiceProvider
    extends $NotifierProvider<ComicService, ComicStore> {
  ComicServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comicServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comicServiceHash();

  @$internal
  @override
  ComicService create() => ComicService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComicStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComicStore>(value),
    );
  }
}

String _$comicServiceHash() => r'6c82c7c1f3c13519bd306d7795e1629627268f5c';

abstract class _$ComicService extends $Notifier<ComicStore> {
  ComicStore build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ComicStore, ComicStore>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ComicStore, ComicStore>,
              ComicStore,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
