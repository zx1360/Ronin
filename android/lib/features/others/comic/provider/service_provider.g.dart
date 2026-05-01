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
String _$deletedInfosHash() => r'75689efc5e105a5a473b4dfa473979366b14c08d';

/// 获取需要删除的漫画记录
///
/// 返回 coverImage 文件不存在的漫画及其关联数据。
///
/// Copied from [deletedInfos].
@ProviderFor(deletedInfos)
final deletedInfosProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  deletedInfos,
  name: r'deletedInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$deletedInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef DeletedInfosRef = AutoDisposeFutureProviderRef<Map<String, dynamic>>;
String _$newInfosHash() => r'31c6c6672517c3c0c37d1a95cdf6dee471a394f5';

/// 扫描未记录的新漫画目录
///
/// 只处理尚未在数据库中的漫画目录。
///
/// Copied from [newInfos].
@ProviderFor(newInfos)
final newInfosProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>>.internal(
  newInfos,
  name: r'newInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$newInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef NewInfosRef = AutoDisposeFutureProviderRef<Map<String, dynamic>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
