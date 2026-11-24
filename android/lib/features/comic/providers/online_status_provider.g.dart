// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'online_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 获取所有在线漫画信息（不过滤，由 UI 层控制可见性）

@ProviderFor(comicsOnline)
final comicsOnlineProvider = ComicsOnlineProvider._();

/// 获取所有在线漫画信息（不过滤，由 UI 层控制可见性）

final class ComicsOnlineProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComicInfo>>,
          List<ComicInfo>,
          FutureOr<List<ComicInfo>>
        >
    with $FutureModifier<List<ComicInfo>>, $FutureProvider<List<ComicInfo>> {
  /// 获取所有在线漫画信息（不过滤，由 UI 层控制可见性）
  ComicsOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comicsOnlineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comicsOnlineHash();

  @$internal
  @override
  $FutureProviderElement<List<ComicInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ComicInfo>> create(Ref ref) {
    return comicsOnline(ref);
  }
}

String _$comicsOnlineHash() => r'f8239fd920726cc90663963774157d0a6c24ebec';

/// 根据漫画 ID 获取对应的章节信息

@ProviderFor(onlineChaptersWithComicId)
final onlineChaptersWithComicIdProvider = OnlineChaptersWithComicIdFamily._();

/// 根据漫画 ID 获取对应的章节信息

final class OnlineChaptersWithComicIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChapterInfo>>,
          List<ChapterInfo>,
          FutureOr<List<ChapterInfo>>
        >
    with
        $FutureModifier<List<ChapterInfo>>,
        $FutureProvider<List<ChapterInfo>> {
  /// 根据漫画 ID 获取对应的章节信息
  OnlineChaptersWithComicIdProvider._({
    required OnlineChaptersWithComicIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'onlineChaptersWithComicIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$onlineChaptersWithComicIdHash();

  @override
  String toString() {
    return r'onlineChaptersWithComicIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ChapterInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChapterInfo>> create(Ref ref) {
    final argument = this.argument as String;
    return onlineChaptersWithComicId(ref, comicId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OnlineChaptersWithComicIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$onlineChaptersWithComicIdHash() =>
    r'dd4f5c78d7cd7505a66aec87e3f6fd90ea60d2ad';

/// 根据漫画 ID 获取对应的章节信息

final class OnlineChaptersWithComicIdFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ChapterInfo>>, String> {
  OnlineChaptersWithComicIdFamily._()
    : super(
        retry: null,
        name: r'onlineChaptersWithComicIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据漫画 ID 获取对应的章节信息

  OnlineChaptersWithComicIdProvider call({required String comicId}) =>
      OnlineChaptersWithComicIdProvider._(argument: comicId, from: this);

  @override
  String toString() => r'onlineChaptersWithComicIdProvider';
}

/// 根据章节 ID 获取对应的图片信息

@ProviderFor(onlineImagesWithChapterId)
final onlineImagesWithChapterIdProvider = OnlineImagesWithChapterIdFamily._();

/// 根据章节 ID 获取对应的图片信息

final class OnlineImagesWithChapterIdProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Map<String, dynamic>>>,
          List<Map<String, dynamic>>,
          FutureOr<List<Map<String, dynamic>>>
        >
    with
        $FutureModifier<List<Map<String, dynamic>>>,
        $FutureProvider<List<Map<String, dynamic>>> {
  /// 根据章节 ID 获取对应的图片信息
  OnlineImagesWithChapterIdProvider._({
    required OnlineImagesWithChapterIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'onlineImagesWithChapterIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$onlineImagesWithChapterIdHash();

  @override
  String toString() {
    return r'onlineImagesWithChapterIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Map<String, dynamic>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Map<String, dynamic>>> create(Ref ref) {
    final argument = this.argument as String;
    return onlineImagesWithChapterId(ref, chapterId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is OnlineImagesWithChapterIdProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$onlineImagesWithChapterIdHash() =>
    r'f74edf57b18977798d07c808d0b74003b018ac4c';

/// 根据章节 ID 获取对应的图片信息

final class OnlineImagesWithChapterIdFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<Map<String, dynamic>>>,
          String
        > {
  OnlineImagesWithChapterIdFamily._()
    : super(
        retry: null,
        name: r'onlineImagesWithChapterIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据章节 ID 获取对应的图片信息

  OnlineImagesWithChapterIdProvider call({required String chapterId}) =>
      OnlineImagesWithChapterIdProvider._(argument: chapterId, from: this);

  @override
  String toString() => r'onlineImagesWithChapterIdProvider';
}
