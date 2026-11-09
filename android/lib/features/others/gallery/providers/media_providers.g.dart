// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nextMediaAssetHash() => r'6fb007e93e6f936e3d20933e34d66c7cd6955664';

/// 下一个未删除的媒体文件 Provider（用于预览小窗）
/// 如果不存在下一个文件，返回 null
///
/// Copied from [nextMediaAsset].
@ProviderFor(nextMediaAsset)
final nextMediaAssetProvider = AutoDisposeProvider<MediaAsset?>.internal(
  nextMediaAsset,
  name: r'nextMediaAssetProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nextMediaAssetHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NextMediaAssetRef = AutoDisposeProviderRef<MediaAsset?>;
String _$mediaAssetListHash() => r'f05dd832400c76173f8cace6240a9cc2de87cae7';

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 包含已删除)
///
/// 读取持久工作副本；媒体编辑经操作表回传服务端。
///
/// Copied from [MediaAssetList].
@ProviderFor(MediaAssetList)
final mediaAssetListProvider =
    AutoDisposeAsyncNotifierProvider<MediaAssetList, List<MediaAsset>>.internal(
  MediaAssetList.new,
  name: r'mediaAssetListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mediaAssetListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MediaAssetList = AutoDisposeAsyncNotifier<List<MediaAsset>>;
String _$currentMediaAssetHash() => r'2a1fc259afdb37606c8df51d7ea94c7f39ec088f';

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）
///
/// Copied from [CurrentMediaAsset].
@ProviderFor(CurrentMediaAsset)
final currentMediaAssetProvider =
    AutoDisposeNotifierProvider<CurrentMediaAsset, MediaAsset?>.internal(
  CurrentMediaAsset.new,
  name: r'currentMediaAssetProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentMediaAssetHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CurrentMediaAsset = AutoDisposeNotifier<MediaAsset?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
