// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BrowseManager)
final browseManagerProvider = BrowseManagerProvider._();

final class BrowseManagerProvider
    extends $NotifierProvider<BrowseManager, BrowseSettings> {
  BrowseManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'browseManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$browseManagerHash();

  @$internal
  @override
  BrowseManager create() => BrowseManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BrowseSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BrowseSettings>(value),
    );
  }
}

String _$browseManagerHash() => r'5bc74dffa78693cc1de8cf866f4a358e63da444e';

abstract class _$BrowseManager extends $Notifier<BrowseSettings> {
  BrowseSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BrowseSettings, BrowseSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BrowseSettings, BrowseSettings>,
              BrowseSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
