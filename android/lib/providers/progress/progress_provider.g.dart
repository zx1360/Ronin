// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProgressService)
final progressServiceProvider = ProgressServiceProvider._();

final class ProgressServiceProvider
    extends $NotifierProvider<ProgressService, Progress> {
  ProgressServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'progressServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$progressServiceHash();

  @$internal
  @override
  ProgressService create() => ProgressService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Progress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Progress>(value),
    );
  }
}

String _$progressServiceHash() => r'e76a9decc5b6452ad88a8c1aee6f9095a1e6fe0b';

abstract class _$ProgressService extends $Notifier<Progress> {
  Progress build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Progress, Progress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Progress, Progress>,
              Progress,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
