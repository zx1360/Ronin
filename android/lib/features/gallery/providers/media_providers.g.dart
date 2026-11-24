// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GalleryGroup)
final galleryGroupProvider = GalleryGroupProvider._();

final class GalleryGroupProvider
    extends $NotifierProvider<GalleryGroup, ({int index, String leadId})?> {
  GalleryGroupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryGroupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryGroupHash();

  @$internal
  @override
  GalleryGroup create() => GalleryGroup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({int index, String leadId})? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({int index, String leadId})?>(
        value,
      ),
    );
  }
}

String _$galleryGroupHash() => r'20c443c72937faaafc37eda15d5cb0db5fbb1ded';

abstract class _$GalleryGroup extends $Notifier<({int index, String leadId})?> {
  ({int index, String leadId})? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ({int index, String leadId})?,
              ({int index, String leadId})?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ({int index, String leadId})?,
                ({int index, String leadId})?
              >,
              ({int index, String leadId})?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 媒体编辑通过操作表提交，查询流提供工作副本。

@ProviderFor(MediaAssetList)
final mediaAssetListProvider = MediaAssetListProvider._();

/// 媒体编辑通过操作表提交，查询流提供工作副本。
final class MediaAssetListProvider
    extends $StreamNotifierProvider<MediaAssetList, List<MediaAsset>> {
  /// 媒体编辑通过操作表提交，查询流提供工作副本。
  MediaAssetListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaAssetListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaAssetListHash();

  @$internal
  @override
  MediaAssetList create() => MediaAssetList();
}

String _$mediaAssetListHash() => r'f6ed1b2bc97ac88cb20e039daa4e07ac89077a8e';

/// 媒体编辑通过操作表提交，查询流提供工作副本。

abstract class _$MediaAssetList extends $StreamNotifier<List<MediaAsset>> {
  Stream<List<MediaAsset>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<MediaAsset>>, List<MediaAsset>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaAsset>>, List<MediaAsset>>,
              AsyncValue<List<MediaAsset>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）

@ProviderFor(CurrentMediaAsset)
final currentMediaAssetProvider = CurrentMediaAssetProvider._();

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）
final class CurrentMediaAssetProvider
    extends $NotifierProvider<CurrentMediaAsset, MediaAsset?> {
  /// 当前媒体文件 Provider
  /// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）
  CurrentMediaAssetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMediaAssetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMediaAssetHash();

  @$internal
  @override
  CurrentMediaAsset create() => CurrentMediaAsset();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaAsset? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaAsset?>(value),
    );
  }
}

String _$currentMediaAssetHash() => r'eb6d0cde101a857c699db1c94a8d3edc1bbeab38';

/// 当前媒体文件 Provider
/// 如果当前索引指向已删除文件，返回该文件（让 UI 层处理跳过逻辑）

abstract class _$CurrentMediaAsset extends $Notifier<MediaAsset?> {
  MediaAsset? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MediaAsset?, MediaAsset?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MediaAsset?, MediaAsset?>,
              MediaAsset?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 下一个未删除的媒体文件 Provider（用于预览小窗）
/// 如果不存在下一个文件，返回 null

@ProviderFor(nextMediaAsset)
final nextMediaAssetProvider = NextMediaAssetProvider._();

/// 下一个未删除的媒体文件 Provider（用于预览小窗）
/// 如果不存在下一个文件，返回 null

final class NextMediaAssetProvider
    extends $FunctionalProvider<MediaAsset?, MediaAsset?, MediaAsset?>
    with $Provider<MediaAsset?> {
  /// 下一个未删除的媒体文件 Provider（用于预览小窗）
  /// 如果不存在下一个文件，返回 null
  NextMediaAssetProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nextMediaAssetProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nextMediaAssetHash();

  @$internal
  @override
  $ProviderElement<MediaAsset?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaAsset? create(Ref ref) {
    return nextMediaAsset(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaAsset? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaAsset?>(value),
    );
  }
}

String _$nextMediaAssetHash() => r'21fd1b849745ea6800c024b80539004a58875517';
