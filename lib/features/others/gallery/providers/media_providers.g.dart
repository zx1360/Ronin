// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mediaAssetListHash() => r'7259d15e1ce82c0a33bf2bc9bd281e88bf64fe67';

/// 媒体文件列表 Provider (按 captured_at 升序, 仅主文件)
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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
