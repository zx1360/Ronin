// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mediaAssetListHash() => r'297ba6c0c0bd638fea808b5c1b7bd6dd4060dc33';

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件, 排除已删除)
/// 用于 gallery_page 的主浏览视图
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
String _$currentMediaAssetHash() => r'76f730c74e8f184265fe6e51f33335b6bfa8c016';

/// 当前媒体文件 Provider
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
String _$allMediaAssetListHash() => r'f7d71eacb11ac0de967c5f122bd44b9b6e6bd0f2';

/// 全部媒体文件列表 Provider (包括已删除，仅主文件)
/// 用于 medias_gridview_page 显示所有文件
///
/// Copied from [AllMediaAssetList].
@ProviderFor(AllMediaAssetList)
final allMediaAssetListProvider = AutoDisposeAsyncNotifierProvider<
    AllMediaAssetList, List<MediaAsset>>.internal(
  AllMediaAssetList.new,
  name: r'allMediaAssetListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allMediaAssetListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AllMediaAssetList = AutoDisposeAsyncNotifier<List<MediaAsset>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
