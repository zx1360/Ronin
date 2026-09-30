// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'smart_album_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$smartAlbumControllerHash() =>
    r'a97fe3a1654bc52b3307b0b8635abdd8dc189c42';

/// 智能相册页控制器：检索、以图搜图、人物分组与 AI 分析结果的取数逻辑。
///
/// 只消费服务端 AI 能力，不写本地缓存；随页面存活（离开页面即重置，
/// 与页面自身持有状态时的行为一致）。需要跨次进入保留结果时改为 keepAlive。
///
/// Copied from [SmartAlbumController].
@ProviderFor(SmartAlbumController)
final smartAlbumControllerProvider =
    AutoDisposeNotifierProvider<SmartAlbumController, SmartAlbumState>.internal(
  SmartAlbumController.new,
  name: r'smartAlbumControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$smartAlbumControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SmartAlbumController = AutoDisposeNotifier<SmartAlbumState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
