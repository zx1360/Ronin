// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryDatabaseHash() => r'4035a38a451711598ab97fe492543d81a93e61b2';

/// 数据库服务 Provider
///
/// Copied from [galleryDatabase].
@ProviderFor(galleryDatabase)
final galleryDatabaseProvider = Provider<GalleryDatabaseService>.internal(
  galleryDatabase,
  name: r'galleryDatabaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDatabaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryDatabaseRef = ProviderRef<GalleryDatabaseService>;
String _$galleryStorageHash() => r'e3d91c97f363aec8568be9046fedbb3cf4478447';

/// 文件存储服务 Provider
///
/// Copied from [galleryStorage].
@ProviderFor(galleryStorage)
final galleryStorageProvider = Provider<GalleryStorageService>.internal(
  galleryStorage,
  name: r'galleryStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef GalleryStorageRef = ProviderRef<GalleryStorageService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
