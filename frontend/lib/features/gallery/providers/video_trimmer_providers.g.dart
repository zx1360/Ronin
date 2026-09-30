// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_trimmer_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoTrimHash() => r'ee6c0cba88ac10e0eaf1320176f96a3e6ed0aa99';

/// 视频剪辑: 时长加载 / 区间调整 / 帧预览 / 保存
///
/// 仅用后端 `frame` 接口的单帧图片做预览, 不引入视频播放器。
///
/// Copied from [VideoTrim].
@ProviderFor(VideoTrim)
final videoTrimProvider =
    AutoDisposeNotifierProvider<VideoTrim, VideoTrimState>.internal(
  VideoTrim.new,
  name: r'videoTrimProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$videoTrimHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$VideoTrim = AutoDisposeNotifier<VideoTrimState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
