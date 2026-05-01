// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$backupJsonDataHash() => r'fb640264e3e4392762b7cb2e74b0c354dbeca672';

/// ============================================================================
/// 备份相关的 Providers
/// 提供数据的序列化和图片路径获取
/// ============================================================================
/// JSON 数据 Provider - 用于数据备份
///
/// Copied from [backupJsonData].
@ProviderFor(backupJsonData)
final backupJsonDataProvider =
    AutoDisposeProvider<Map<String, dynamic>>.internal(
  backupJsonData,
  name: r'backupJsonDataProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$backupJsonDataHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BackupJsonDataRef = AutoDisposeProviderRef<Map<String, dynamic>>;
String _$taskImagePathsHash() => r'f189045661bb200cf534f078f2cc6dc07e5ce12a';

/// 图片路径 Provider - 获取所有任务图片的相对路径
///
/// Copied from [taskImagePaths].
@ProviderFor(taskImagePaths)
final taskImagePathsProvider = AutoDisposeProvider<List<String>>.internal(
  taskImagePaths,
  name: r'taskImagePathsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$taskImagePathsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef TaskImagePathsRef = AutoDisposeProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
