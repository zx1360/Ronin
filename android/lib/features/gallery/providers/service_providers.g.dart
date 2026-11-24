// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 数据库服务 Provider

@ProviderFor(galleryDatabase)
final galleryDatabaseProvider = GalleryDatabaseProvider._();

/// 数据库服务 Provider

final class GalleryDatabaseProvider
    extends
        $FunctionalProvider<
          GalleryDatabaseService,
          GalleryDatabaseService,
          GalleryDatabaseService
        >
    with $Provider<GalleryDatabaseService> {
  /// 数据库服务 Provider
  GalleryDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDatabaseHash();

  @$internal
  @override
  $ProviderElement<GalleryDatabaseService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GalleryDatabaseService create(Ref ref) {
    return galleryDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryDatabaseService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryDatabaseService>(value),
    );
  }
}

String _$galleryDatabaseHash() => r'ca512832ea2bde74de461eca7d878f8e90136269';

/// 文件存储服务 Provider

@ProviderFor(galleryStorage)
final galleryStorageProvider = GalleryStorageProvider._();

/// 文件存储服务 Provider

final class GalleryStorageProvider
    extends
        $FunctionalProvider<
          GalleryStorageService,
          GalleryStorageService,
          GalleryStorageService
        >
    with $Provider<GalleryStorageService> {
  /// 文件存储服务 Provider
  GalleryStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryStorageHash();

  @$internal
  @override
  $ProviderElement<GalleryStorageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GalleryStorageService create(Ref ref) {
    return galleryStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryStorageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryStorageService>(value),
    );
  }
}

String _$galleryStorageHash() => r'479d1d6ba1551dc2ce632dfb2044f4fb4c1ca58f';

@ProviderFor(GalleryFilesRevision)
final galleryFilesRevisionProvider = GalleryFilesRevisionProvider._();

final class GalleryFilesRevisionProvider
    extends $NotifierProvider<GalleryFilesRevision, int> {
  GalleryFilesRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryFilesRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryFilesRevisionHash();

  @$internal
  @override
  GalleryFilesRevision create() => GalleryFilesRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryFilesRevisionHash() =>
    r'a3e607c571dc1eefdad54366fa0e4d19269c29a2';

abstract class _$GalleryFilesRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
