// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 标签树 Provider
///
/// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。

@ProviderFor(TagTree)
final tagTreeProvider = TagTreeProvider._();

/// 标签树 Provider
///
/// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。
final class TagTreeProvider
    extends $StreamNotifierProvider<TagTree, List<Tag>> {
  /// 标签树 Provider
  ///
  /// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。
  TagTreeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagTreeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagTreeHash();

  @$internal
  @override
  TagTree create() => TagTree();
}

String _$tagTreeHash() => r'b930c6a6bd224059beeeef93e4bfe5af5fb253ce';

/// 标签树 Provider
///
/// Gallery 使用离线工作副本；在线相册写入前先确认待回传操作。

abstract class _$TagTree extends $StreamNotifier<List<Tag>> {
  Stream<List<Tag>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Tag>>, List<Tag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Tag>>, List<Tag>>,
              AsyncValue<List<Tag>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 快捷标签（收藏标签，按绑定媒体数降序）

@ProviderFor(favoriteTags)
final favoriteTagsProvider = FavoriteTagsProvider._();

/// 快捷标签（收藏标签，按绑定媒体数降序）

final class FavoriteTagsProvider
    extends $FunctionalProvider<List<Tag>, List<Tag>, List<Tag>>
    with $Provider<List<Tag>> {
  /// 快捷标签（收藏标签，按绑定媒体数降序）
  FavoriteTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteTagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteTagsHash();

  @$internal
  @override
  $ProviderElement<List<Tag>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Tag> create(Ref ref) {
    return favoriteTags(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Tag> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Tag>>(value),
    );
  }
}

String _$favoriteTagsHash() => r'de8dcdf48360fc3bcdd5278730d4e2334cae14ef';

/// 当前媒体文件的标签 Provider（读本地缓存）

@ProviderFor(CurrentMediaTags)
final currentMediaTagsProvider = CurrentMediaTagsProvider._();

/// 当前媒体文件的标签 Provider（读本地缓存）
final class CurrentMediaTagsProvider
    extends $StreamNotifierProvider<CurrentMediaTags, List<Tag>> {
  /// 当前媒体文件的标签 Provider（读本地缓存）
  CurrentMediaTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentMediaTagsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentMediaTagsHash();

  @$internal
  @override
  CurrentMediaTags create() => CurrentMediaTags();
}

String _$currentMediaTagsHash() => r'ce6e4d4944c3981cee1c63678c4defb73d619b7f';

/// 当前媒体文件的标签 Provider（读本地缓存）

abstract class _$CurrentMediaTags extends $StreamNotifier<List<Tag>> {
  Stream<List<Tag>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Tag>>, List<Tag>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Tag>>, List<Tag>>,
              AsyncValue<List<Tag>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
