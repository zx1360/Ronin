// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$nextMediaAssetHash() => r'acdb3ec4201686aefa772a53c6440c68b4f6e22e';

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
String _$mediaAssetListHash() => r'6beabfb55f86d0bf35e0aba72f2da16a5e7d15e6';

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 包含已删除)
/// 统一使用这个列表，索引保持稳定
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
String _$currentMediaAssetHash() => r'8a3c0029b21ded72ab4d944429865cb3eeb474d0';

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
