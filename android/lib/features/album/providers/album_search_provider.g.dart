// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'album_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AlbumSearchController)
final albumSearchControllerProvider = AlbumSearchControllerProvider._();

final class AlbumSearchControllerProvider
    extends $NotifierProvider<AlbumSearchController, AlbumSearchState> {
  AlbumSearchControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'albumSearchControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$albumSearchControllerHash();

  @$internal
  @override
  AlbumSearchController create() => AlbumSearchController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlbumSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlbumSearchState>(value),
    );
  }
}

String _$albumSearchControllerHash() =>
    r'38db14746851afe2f44671861de7fad230cf1aa1';

abstract class _$AlbumSearchController extends $Notifier<AlbumSearchState> {
  AlbumSearchState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AlbumSearchState, AlbumSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AlbumSearchState, AlbumSearchState>,
              AlbumSearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
