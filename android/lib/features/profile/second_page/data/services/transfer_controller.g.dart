// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TransferController)
final transferControllerProvider = TransferControllerProvider._();

final class TransferControllerProvider
    extends $NotifierProvider<TransferController, TransferProgress> {
  TransferControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'transferControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$transferControllerHash();

  @$internal
  @override
  TransferController create() => TransferController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TransferProgress value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TransferProgress>(value),
    );
  }
}

String _$transferControllerHash() =>
    r'39547e4b0a5d1781989f1c5015cece605f474f24';

abstract class _$TransferController extends $Notifier<TransferProgress> {
  TransferProgress build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TransferProgress, TransferProgress>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TransferProgress, TransferProgress>,
              TransferProgress,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
