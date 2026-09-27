// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_editor_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imageEditHash() => r'ed96a3992203609f655994cdfc7a6abafac3a78f';

/// 图片编辑: 旋转 / 裁切 / 保存
///
/// 页面只保留手势与布局, 编辑数值与写路径都在这里。
///
/// Copied from [ImageEdit].
@ProviderFor(ImageEdit)
final imageEditProvider =
    AutoDisposeNotifierProvider<ImageEdit, ImageEditState>.internal(
  ImageEdit.new,
  name: r'imageEditProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$imageEditHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ImageEdit = AutoDisposeNotifier<ImageEditState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
