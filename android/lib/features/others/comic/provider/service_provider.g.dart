// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$allInfosHash() => r'12b6a99eae618ea0206d4381de20cd8abac4f63a';

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
String _$deletedInfosHash() => r'5cc9dbf9a63c7f79e6bba66311f7dd4c6cda35fc';

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
String _$newInfosHash() => r'9c126246ffe8460140663f2c23d3166e17b5b804';

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
