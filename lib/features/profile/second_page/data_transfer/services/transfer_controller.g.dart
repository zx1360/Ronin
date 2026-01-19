// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$transferControllerHash() =>
    r'4575f524199af2a119b40c73c2c1bc7690c931ee';

/// 数据传输控制器
///
/// 提供同步和备份功能，管理传输状态。
///
/// Copied from [TransferController].
@ProviderFor(TransferController)
final transferControllerProvider =
    AutoDisposeNotifierProvider<TransferController, TransferProgress>.internal(
      TransferController.new,
      name: r'transferControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$transferControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TransferController = AutoDisposeNotifier<TransferProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
