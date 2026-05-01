// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$comicInfosHash() => r'82eae5d4f68dce760a3bab7fb67555f403732655';

/// 所有本地漫画信息（按拼音升序排列）
///
/// 对于含有中文的漫画名，按拼音首字母排序。
///
/// Copied from [comicInfos].
@ProviderFor(comicInfos)
final comicInfosProvider = AutoDisposeProvider<List<ComicInfo>>.internal(
  comicInfos,
  name: r'comicInfosProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$comicInfosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ComicInfosRef = AutoDisposeProviderRef<List<ComicInfo>>;
String _$comicPrefWithComicIdHash() =>
    r'e7356a15d0a93a610b9181d66a02d9912a964930';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 获取指定漫画的阅读偏好
///
/// 如果不存在则返回默认偏好（从第0章开始）。
///
/// Copied from [comicPrefWithComicId].
@ProviderFor(comicPrefWithComicId)
const comicPrefWithComicIdProvider = ComicPrefWithComicIdFamily();

/// 获取指定漫画的阅读偏好
///
/// 如果不存在则返回默认偏好（从第0章开始）。
///
/// Copied from [comicPrefWithComicId].
class ComicPrefWithComicIdFamily extends Family<ComicPreference> {
  /// 获取指定漫画的阅读偏好
  ///
  /// 如果不存在则返回默认偏好（从第0章开始）。
  ///
  /// Copied from [comicPrefWithComicId].
  const ComicPrefWithComicIdFamily();

  /// 获取指定漫画的阅读偏好
  ///
  /// 如果不存在则返回默认偏好（从第0章开始）。
  ///
  /// Copied from [comicPrefWithComicId].
  ComicPrefWithComicIdProvider call({
    required String comicId,
  }) {
    return ComicPrefWithComicIdProvider(
      comicId: comicId,
    );
  }

  @override
  ComicPrefWithComicIdProvider getProviderOverride(
    covariant ComicPrefWithComicIdProvider provider,
  ) {
    return call(
      comicId: provider.comicId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'comicPrefWithComicIdProvider';
}

/// 获取指定漫画的阅读偏好
///
/// 如果不存在则返回默认偏好（从第0章开始）。
///
/// Copied from [comicPrefWithComicId].
class ComicPrefWithComicIdProvider
    extends AutoDisposeProvider<ComicPreference> {
  /// 获取指定漫画的阅读偏好
  ///
  /// 如果不存在则返回默认偏好（从第0章开始）。
  ///
  /// Copied from [comicPrefWithComicId].
  ComicPrefWithComicIdProvider({
    required String comicId,
  }) : this._internal(
          (ref) => comicPrefWithComicId(
            ref as ComicPrefWithComicIdRef,
            comicId: comicId,
          ),
          from: comicPrefWithComicIdProvider,
          name: r'comicPrefWithComicIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$comicPrefWithComicIdHash,
          dependencies: ComicPrefWithComicIdFamily._dependencies,
          allTransitiveDependencies:
              ComicPrefWithComicIdFamily._allTransitiveDependencies,
          comicId: comicId,
        );

  ComicPrefWithComicIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.comicId,
  }) : super.internal();

  final String comicId;

  @override
  Override overrideWith(
    ComicPreference Function(ComicPrefWithComicIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ComicPrefWithComicIdProvider._internal(
        (ref) => create(ref as ComicPrefWithComicIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        comicId: comicId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<ComicPreference> createElement() {
    return _ComicPrefWithComicIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ComicPrefWithComicIdProvider && other.comicId == comicId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, comicId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ComicPrefWithComicIdRef on AutoDisposeProviderRef<ComicPreference> {
  /// The parameter `comicId` of this provider.
  String get comicId;
}

class _ComicPrefWithComicIdProviderElement
    extends AutoDisposeProviderElement<ComicPreference>
    with ComicPrefWithComicIdRef {
  _ComicPrefWithComicIdProviderElement(super.provider);

  @override
  String get comicId => (origin as ComicPrefWithComicIdProvider).comicId;
}

String _$chaptersWithComicIdHash() =>
    r'9592109cace153ea9f3ef32ac53b7c3b373c04b7';

/// 获取指定漫画的所有章节信息
///
/// 按章节索引升序排列。
///
/// Copied from [chaptersWithComicId].
@ProviderFor(chaptersWithComicId)
const chaptersWithComicIdProvider = ChaptersWithComicIdFamily();

/// 获取指定漫画的所有章节信息
///
/// 按章节索引升序排列。
///
/// Copied from [chaptersWithComicId].
class ChaptersWithComicIdFamily extends Family<AsyncValue<List<ChapterInfo>>> {
  /// 获取指定漫画的所有章节信息
  ///
  /// 按章节索引升序排列。
  ///
  /// Copied from [chaptersWithComicId].
  const ChaptersWithComicIdFamily();

  /// 获取指定漫画的所有章节信息
  ///
  /// 按章节索引升序排列。
  ///
  /// Copied from [chaptersWithComicId].
  ChaptersWithComicIdProvider call({
    required String comicId,
  }) {
    return ChaptersWithComicIdProvider(
      comicId: comicId,
    );
  }

  @override
  ChaptersWithComicIdProvider getProviderOverride(
    covariant ChaptersWithComicIdProvider provider,
  ) {
    return call(
      comicId: provider.comicId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'chaptersWithComicIdProvider';
}

/// 获取指定漫画的所有章节信息
///
/// 按章节索引升序排列。
///
/// Copied from [chaptersWithComicId].
class ChaptersWithComicIdProvider
    extends AutoDisposeFutureProvider<List<ChapterInfo>> {
  /// 获取指定漫画的所有章节信息
  ///
  /// 按章节索引升序排列。
  ///
  /// Copied from [chaptersWithComicId].
  ChaptersWithComicIdProvider({
    required String comicId,
  }) : this._internal(
          (ref) => chaptersWithComicId(
            ref as ChaptersWithComicIdRef,
            comicId: comicId,
          ),
          from: chaptersWithComicIdProvider,
          name: r'chaptersWithComicIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chaptersWithComicIdHash,
          dependencies: ChaptersWithComicIdFamily._dependencies,
          allTransitiveDependencies:
              ChaptersWithComicIdFamily._allTransitiveDependencies,
          comicId: comicId,
        );

  ChaptersWithComicIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.comicId,
  }) : super.internal();

  final String comicId;

  @override
  Override overrideWith(
    FutureOr<List<ChapterInfo>> Function(ChaptersWithComicIdRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ChaptersWithComicIdProvider._internal(
        (ref) => create(ref as ChaptersWithComicIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        comicId: comicId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<ChapterInfo>> createElement() {
    return _ChaptersWithComicIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChaptersWithComicIdProvider && other.comicId == comicId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, comicId.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin ChaptersWithComicIdRef
    on AutoDisposeFutureProviderRef<List<ChapterInfo>> {
  /// The parameter `comicId` of this provider.
  String get comicId;
}

class _ChaptersWithComicIdProviderElement
    extends AutoDisposeFutureProviderElement<List<ChapterInfo>>
    with ChaptersWithComicIdRef {
  _ChaptersWithComicIdProviderElement(super.provider);

  @override
  String get comicId => (origin as ChaptersWithComicIdProvider).comicId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
