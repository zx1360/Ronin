// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_album_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SmartAlbumController)
final smartAlbumControllerProvider = SmartAlbumControllerProvider._();

final class SmartAlbumControllerProvider
    extends $NotifierProvider<SmartAlbumController, SmartAlbumState> {
  SmartAlbumControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'smartAlbumControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$smartAlbumControllerHash();

  @$internal
  @override
  SmartAlbumController create() => SmartAlbumController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SmartAlbumState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SmartAlbumState>(value),
    );
  }
}

String _$smartAlbumControllerHash() =>
    r'fa83fa899dd76bc5c18789b87020c7dd17ce80e4';

abstract class _$SmartAlbumController extends $Notifier<SmartAlbumState> {
  SmartAlbumState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SmartAlbumState, SmartAlbumState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SmartAlbumState, SmartAlbumState>,
              SmartAlbumState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
