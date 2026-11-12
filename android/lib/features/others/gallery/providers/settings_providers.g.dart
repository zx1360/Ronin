// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GalleryAutoOrientation)
final galleryAutoOrientationProvider = GalleryAutoOrientationProvider._();

final class GalleryAutoOrientationProvider
    extends $NotifierProvider<GalleryAutoOrientation, bool> {
  GalleryAutoOrientationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryAutoOrientationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryAutoOrientationHash();

  @$internal
  @override
  GalleryAutoOrientation create() => GalleryAutoOrientation();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$galleryAutoOrientationHash() =>
    r'3c799ff5dcb017899640d57d0042f3a2dacdde2a';

abstract class _$GalleryAutoOrientation extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(galleryStoredIndex)
final galleryStoredIndexProvider = GalleryStoredIndexProvider._();

final class GalleryStoredIndexProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  GalleryStoredIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryStoredIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryStoredIndexHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return galleryStoredIndex(ref);
  }
}

String _$galleryStoredIndexHash() =>
    r'c214e8458f76347738ff8d4b6dcf6fb95153dd6a';

@ProviderFor(GalleryCurrentIndex)
final galleryCurrentIndexProvider = GalleryCurrentIndexProvider._();

final class GalleryCurrentIndexProvider
    extends $NotifierProvider<GalleryCurrentIndex, int> {
  GalleryCurrentIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryCurrentIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryCurrentIndexHash();

  @$internal
  @override
  GalleryCurrentIndex create() => GalleryCurrentIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryCurrentIndexHash() =>
    r'd3959707f4f246c0842769641d0ba52281be9dde';

abstract class _$GalleryCurrentIndex extends $Notifier<int> {
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

/// 网格视图每行数量 (3, 4, 8, 16)

@ProviderFor(GalleryGridColumns)
final galleryGridColumnsProvider = GalleryGridColumnsProvider._();

/// 网格视图每行数量 (3, 4, 8, 16)
final class GalleryGridColumnsProvider
    extends $NotifierProvider<GalleryGridColumns, int> {
  /// 网格视图每行数量 (3, 4, 8, 16)
  GalleryGridColumnsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryGridColumnsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryGridColumnsHash();

  @$internal
  @override
  GalleryGridColumns create() => GalleryGridColumns();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryGridColumnsHash() =>
    r'7911eebfac5c3da40dab130ee2042944283b58b4';

/// 网格视图每行数量 (3, 4, 8, 16)

abstract class _$GalleryGridColumns extends $Notifier<int> {
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

/// 预览小窗开关设置（默认开启）

@ProviderFor(GalleryPreviewWindowEnabled)
final galleryPreviewWindowEnabledProvider =
    GalleryPreviewWindowEnabledProvider._();

/// 预览小窗开关设置（默认开启）
final class GalleryPreviewWindowEnabledProvider
    extends $NotifierProvider<GalleryPreviewWindowEnabled, bool> {
  /// 预览小窗开关设置（默认开启）
  GalleryPreviewWindowEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryPreviewWindowEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryPreviewWindowEnabledHash();

  @$internal
  @override
  GalleryPreviewWindowEnabled create() => GalleryPreviewWindowEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$galleryPreviewWindowEnabledHash() =>
    r'5bb0b46de22e48d827b3ecb2b6eb3991f7e9432c';

/// 预览小窗开关设置（默认开启）

abstract class _$GalleryPreviewWindowEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 下载 MIME 类型筛选（空=全部, image, video）

@ProviderFor(GalleryDownloadMimeFilter)
final galleryDownloadMimeFilterProvider = GalleryDownloadMimeFilterProvider._();

/// 下载 MIME 类型筛选（空=全部, image, video）
final class GalleryDownloadMimeFilterProvider
    extends $NotifierProvider<GalleryDownloadMimeFilter, String> {
  /// 下载 MIME 类型筛选（空=全部, image, video）
  GalleryDownloadMimeFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadMimeFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadMimeFilterHash();

  @$internal
  @override
  GalleryDownloadMimeFilter create() => GalleryDownloadMimeFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$galleryDownloadMimeFilterHash() =>
    r'7a7dc54c5e35413f3a96eb8867d8582ea4df9690';

/// 下载 MIME 类型筛选（空=全部, image, video）

abstract class _$GalleryDownloadMimeFilter extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 下载排序字段（空=默认 sync_count 升序）

@ProviderFor(GalleryDownloadSortBy)
final galleryDownloadSortByProvider = GalleryDownloadSortByProvider._();

/// 下载排序字段（空=默认 sync_count 升序）
final class GalleryDownloadSortByProvider
    extends $NotifierProvider<GalleryDownloadSortBy, String> {
  /// 下载排序字段（空=默认 sync_count 升序）
  GalleryDownloadSortByProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadSortByProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadSortByHash();

  @$internal
  @override
  GalleryDownloadSortBy create() => GalleryDownloadSortBy();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$galleryDownloadSortByHash() =>
    r'3797fdb0fa3f7c7684badfc6db67993e1a38809d';

/// 下载排序字段（空=默认 sync_count 升序）

abstract class _$GalleryDownloadSortBy extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 下载排序方向（asc/desc）

@ProviderFor(GalleryDownloadSortOrder)
final galleryDownloadSortOrderProvider = GalleryDownloadSortOrderProvider._();

/// 下载排序方向（asc/desc）
final class GalleryDownloadSortOrderProvider
    extends $NotifierProvider<GalleryDownloadSortOrder, String> {
  /// 下载排序方向（asc/desc）
  GalleryDownloadSortOrderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadSortOrderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadSortOrderHash();

  @$internal
  @override
  GalleryDownloadSortOrder create() => GalleryDownloadSortOrder();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$galleryDownloadSortOrderHash() =>
    r'420720d60be3cc8239d89ae11518cae9f6cad886';

/// 下载排序方向（asc/desc）

abstract class _$GalleryDownloadSortOrder extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 下载年份筛选（0=不筛选）

@ProviderFor(GalleryDownloadYear)
final galleryDownloadYearProvider = GalleryDownloadYearProvider._();

/// 下载年份筛选（0=不筛选）
final class GalleryDownloadYearProvider
    extends $NotifierProvider<GalleryDownloadYear, int> {
  /// 下载年份筛选（0=不筛选）
  GalleryDownloadYearProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadYearProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadYearHash();

  @$internal
  @override
  GalleryDownloadYear create() => GalleryDownloadYear();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryDownloadYearHash() =>
    r'246645aef740e7e35b8a5e75e8226f1c1eb97d27';

/// 下载年份筛选（0=不筛选）

abstract class _$GalleryDownloadYear extends $Notifier<int> {
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

/// 下载月份筛选（0=不筛选）

@ProviderFor(GalleryDownloadMonth)
final galleryDownloadMonthProvider = GalleryDownloadMonthProvider._();

/// 下载月份筛选（0=不筛选）
final class GalleryDownloadMonthProvider
    extends $NotifierProvider<GalleryDownloadMonth, int> {
  /// 下载月份筛选（0=不筛选）
  GalleryDownloadMonthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadMonthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadMonthHash();

  @$internal
  @override
  GalleryDownloadMonth create() => GalleryDownloadMonth();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryDownloadMonthHash() =>
    r'bf8a5f4aa2d2abe4ac6a5d13d45cc28ced25581c';

/// 下载月份筛选（0=不筛选）

abstract class _$GalleryDownloadMonth extends $Notifier<int> {
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

/// 下载日期筛选（0=不筛选）

@ProviderFor(GalleryDownloadDay)
final galleryDownloadDayProvider = GalleryDownloadDayProvider._();

/// 下载日期筛选（0=不筛选）
final class GalleryDownloadDayProvider
    extends $NotifierProvider<GalleryDownloadDay, int> {
  /// 下载日期筛选（0=不筛选）
  GalleryDownloadDayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadDayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadDayHash();

  @$internal
  @override
  GalleryDownloadDay create() => GalleryDownloadDay();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$galleryDownloadDayHash() =>
    r'6af43dadb836e1ee27acdde9ef2486f8d8aa23d5';

/// 下载日期筛选（0=不筛选）

abstract class _$GalleryDownloadDay extends $Notifier<int> {
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

/// 下载二次排序字段（空=不进行二次排序）

@ProviderFor(GalleryDownloadSecondarySort)
final galleryDownloadSecondarySortProvider =
    GalleryDownloadSecondarySortProvider._();

/// 下载二次排序字段（空=不进行二次排序）
final class GalleryDownloadSecondarySortProvider
    extends $NotifierProvider<GalleryDownloadSecondarySort, String> {
  /// 下载二次排序字段（空=不进行二次排序）
  GalleryDownloadSecondarySortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryDownloadSecondarySortProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryDownloadSecondarySortHash();

  @$internal
  @override
  GalleryDownloadSecondarySort create() => GalleryDownloadSecondarySort();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$galleryDownloadSecondarySortHash() =>
    r'4976b19a9600f2bd61f443054dc41f8914603789';

/// 下载二次排序字段（空=不进行二次排序）

abstract class _$GalleryDownloadSecondarySort extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 网格预览模式 Provider

@ProviderFor(GalleryGridPreviewModeNotifier)
final galleryGridPreviewModeProvider =
    GalleryGridPreviewModeNotifierProvider._();

/// 网格预览模式 Provider
final class GalleryGridPreviewModeNotifierProvider
    extends
        $NotifierProvider<
          GalleryGridPreviewModeNotifier,
          GalleryGridPreviewMode
        > {
  /// 网格预览模式 Provider
  GalleryGridPreviewModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryGridPreviewModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryGridPreviewModeNotifierHash();

  @$internal
  @override
  GalleryGridPreviewModeNotifier create() => GalleryGridPreviewModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GalleryGridPreviewMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GalleryGridPreviewMode>(value),
    );
  }
}

String _$galleryGridPreviewModeNotifierHash() =>
    r'be3fac5092c9afbd3e273c174f56aa8cc33b70bb';

/// 网格预览模式 Provider

abstract class _$GalleryGridPreviewModeNotifier
    extends $Notifier<GalleryGridPreviewMode> {
  GalleryGridPreviewMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<GalleryGridPreviewMode, GalleryGridPreviewMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GalleryGridPreviewMode, GalleryGridPreviewMode>,
              GalleryGridPreviewMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 标签自动套用开关（默认关闭）
/// 开启后，当前媒体文件的标签会自动套用到下一个成为"当前文件"的媒体上。

@ProviderFor(GalleryTagAutoApplyEnabled)
final galleryTagAutoApplyEnabledProvider =
    GalleryTagAutoApplyEnabledProvider._();

/// 标签自动套用开关（默认关闭）
/// 开启后，当前媒体文件的标签会自动套用到下一个成为"当前文件"的媒体上。
final class GalleryTagAutoApplyEnabledProvider
    extends $NotifierProvider<GalleryTagAutoApplyEnabled, bool> {
  /// 标签自动套用开关（默认关闭）
  /// 开启后，当前媒体文件的标签会自动套用到下一个成为"当前文件"的媒体上。
  GalleryTagAutoApplyEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'galleryTagAutoApplyEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$galleryTagAutoApplyEnabledHash();

  @$internal
  @override
  GalleryTagAutoApplyEnabled create() => GalleryTagAutoApplyEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$galleryTagAutoApplyEnabledHash() =>
    r'247e75b14b63dd990e7b521bd1da9946cf966fc6';

/// 标签自动套用开关（默认关闭）
/// 开启后，当前媒体文件的标签会自动套用到下一个成为"当前文件"的媒体上。

abstract class _$GalleryTagAutoApplyEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
