// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$allInfosHash() => r'df8714f59117fce68264fb311db075e293064995';

/// 扫描漫画目录获取所有漫画和章节元数据
///
/// 遍历 `comics` 目录下的所有子目录，生成 [ComicInfo] 和 [ChapterInfo]。
///
/// Copied from [allInfos].
@ProviderFor(allInfos)
final allInfosProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  allInfos,
  name: r'allInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllInfosRef = AutoDisposeFutureProviderRef<Map<String, dynamic>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
