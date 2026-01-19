// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncBookletWithProgressHash() =>
    r'd29d157efa2ccdc4547f47a99516a070caa5d289';

/// 同步打卡数据（支持进度跟踪和并发下载）
///
/// Copied from [syncBookletWithProgress].
@ProviderFor(syncBookletWithProgress)
final syncBookletWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  syncBookletWithProgress,
  name: r'syncBookletWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncBookletWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SyncBookletWithProgressRef
    = AutoDisposeFutureProviderRef<TransferResult>;
String _$syncEssayWithProgressHash() =>
    r'8d3c7554cbe5ce147b7507119a6428ced7c6b0a8';

/// 同步随笔数据（支持进度跟踪和并发下载）
///
/// Copied from [syncEssayWithProgress].
@ProviderFor(syncEssayWithProgress)
final syncEssayWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  syncEssayWithProgress,
  name: r'syncEssayWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncEssayWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SyncEssayWithProgressRef = AutoDisposeFutureProviderRef<TransferResult>;
String _$syncAllWithProgressHash() =>
    r'2150b7affc9137c1494f835eb25f19803364ecdb';

/// 同步所有数据
///
/// Copied from [syncAllWithProgress].
@ProviderFor(syncAllWithProgress)
final syncAllWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  syncAllWithProgress,
  name: r'syncAllWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncAllWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SyncAllWithProgressRef = AutoDisposeFutureProviderRef<TransferResult>;
String _$backupBookletWithProgressHash() =>
    r'9519b79282e6bf93f7ce5317301dd487905a3c72';

/// 备份打卡数据（支持进度跟踪和并发上传）
///
/// Copied from [backupBookletWithProgress].
@ProviderFor(backupBookletWithProgress)
final backupBookletWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  backupBookletWithProgress,
  name: r'backupBookletWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backupBookletWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BackupBookletWithProgressRef
    = AutoDisposeFutureProviderRef<TransferResult>;
String _$backupEssayWithProgressHash() =>
    r'0ab1c7feeea8bfe3e48f10b915d25442bbe15a61';

/// 备份随笔数据（支持进度跟踪和并发上传）
///
/// Copied from [backupEssayWithProgress].
@ProviderFor(backupEssayWithProgress)
final backupEssayWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  backupEssayWithProgress,
  name: r'backupEssayWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backupEssayWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BackupEssayWithProgressRef
    = AutoDisposeFutureProviderRef<TransferResult>;
String _$backupAllWithProgressHash() =>
    r'960b760ecee953e9cfd3dbdd6f16cc9afee89062';

/// 备份所有数据
///
/// Copied from [backupAllWithProgress].
@ProviderFor(backupAllWithProgress)
final backupAllWithProgressProvider =
    AutoDisposeFutureProvider<TransferResult>.internal(
  backupAllWithProgress,
  name: r'backupAllWithProgressProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backupAllWithProgressHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BackupAllWithProgressRef = AutoDisposeFutureProviderRef<TransferResult>;
String _$transferStateHash() => r'defde9376944355dc090651044d5e872340bea1d';

/// 传输进度状态提供者
///
/// Copied from [TransferState].
@ProviderFor(TransferState)
final transferStateProvider =
    AutoDisposeNotifierProvider<TransferState, TransferProgress>.internal(
  TransferState.new,
  name: r'transferStateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$transferStateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TransferState = AutoDisposeNotifier<TransferProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
