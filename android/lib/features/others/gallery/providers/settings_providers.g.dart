// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$galleryModifiedCountHash() =>
    r'd0c0b8767e9086366e97a72fe955b8e8f5999a7d';

/// modified_count - 记录最后一次操作的媒体文件在队列中的位置
///
/// Copied from [GalleryModifiedCount].
@ProviderFor(GalleryModifiedCount)
final galleryModifiedCountProvider =
    NotifierProvider<GalleryModifiedCount, int>.internal(
  GalleryModifiedCount.new,
  name: r'galleryModifiedCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryModifiedCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryModifiedCount = Notifier<int>;
String _$galleryCurrentIndexHash() =>
    r'0d07dd3f91fb9e2a53eaa051895cdc2145576cc4';

/// 当前浏览位置索引
///
/// Copied from [GalleryCurrentIndex].
@ProviderFor(GalleryCurrentIndex)
final galleryCurrentIndexProvider =
    NotifierProvider<GalleryCurrentIndex, int>.internal(
  GalleryCurrentIndex.new,
  name: r'galleryCurrentIndexProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryCurrentIndexHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryCurrentIndex = Notifier<int>;
String _$galleryGridColumnsHash() =>
    r'7911eebfac5c3da40dab130ee2042944283b58b4';

/// 网格视图每行数量 (3, 4, 8, 16)
///
/// Copied from [GalleryGridColumns].
@ProviderFor(GalleryGridColumns)
final galleryGridColumnsProvider =
    NotifierProvider<GalleryGridColumns, int>.internal(
  GalleryGridColumns.new,
  name: r'galleryGridColumnsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryGridColumnsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryGridColumns = Notifier<int>;
String _$galleryPreviewWindowEnabledHash() =>
    r'5bb0b46de22e48d827b3ecb2b6eb3991f7e9432c';

/// 预览小窗开关设置（默认开启）
///
/// Copied from [GalleryPreviewWindowEnabled].
@ProviderFor(GalleryPreviewWindowEnabled)
final galleryPreviewWindowEnabledProvider =
    NotifierProvider<GalleryPreviewWindowEnabled, bool>.internal(
  GalleryPreviewWindowEnabled.new,
  name: r'galleryPreviewWindowEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryPreviewWindowEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryPreviewWindowEnabled = Notifier<bool>;
String _$galleryDownloadMimeFilterHash() =>
    r'7a7dc54c5e35413f3a96eb8867d8582ea4df9690';

/// 下载 MIME 类型筛选（空=全部, image, video）
///
/// Copied from [GalleryDownloadMimeFilter].
@ProviderFor(GalleryDownloadMimeFilter)
final galleryDownloadMimeFilterProvider =
    NotifierProvider<GalleryDownloadMimeFilter, String>.internal(
  GalleryDownloadMimeFilter.new,
  name: r'galleryDownloadMimeFilterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadMimeFilterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadMimeFilter = Notifier<String>;
String _$galleryDownloadSortByHash() =>
    r'3797fdb0fa3f7c7684badfc6db67993e1a38809d';

/// 下载排序字段（空=默认 sync_count 升序）
///
/// Copied from [GalleryDownloadSortBy].
@ProviderFor(GalleryDownloadSortBy)
final galleryDownloadSortByProvider =
    NotifierProvider<GalleryDownloadSortBy, String>.internal(
  GalleryDownloadSortBy.new,
  name: r'galleryDownloadSortByProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadSortByHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadSortBy = Notifier<String>;
String _$galleryDownloadSortOrderHash() =>
    r'420720d60be3cc8239d89ae11518cae9f6cad886';

/// 下载排序方向（asc/desc）
///
/// Copied from [GalleryDownloadSortOrder].
@ProviderFor(GalleryDownloadSortOrder)
final galleryDownloadSortOrderProvider =
    NotifierProvider<GalleryDownloadSortOrder, String>.internal(
  GalleryDownloadSortOrder.new,
  name: r'galleryDownloadSortOrderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadSortOrderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadSortOrder = Notifier<String>;
String _$galleryDownloadYearHash() =>
    r'246645aef740e7e35b8a5e75e8226f1c1eb97d27';

/// 下载年份筛选（0=不筛选）
///
/// Copied from [GalleryDownloadYear].
@ProviderFor(GalleryDownloadYear)
final galleryDownloadYearProvider =
    NotifierProvider<GalleryDownloadYear, int>.internal(
  GalleryDownloadYear.new,
  name: r'galleryDownloadYearProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadYearHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadYear = Notifier<int>;
String _$galleryDownloadMonthHash() =>
    r'bf8a5f4aa2d2abe4ac6a5d13d45cc28ced25581c';

/// 下载月份筛选（0=不筛选）
///
/// Copied from [GalleryDownloadMonth].
@ProviderFor(GalleryDownloadMonth)
final galleryDownloadMonthProvider =
    NotifierProvider<GalleryDownloadMonth, int>.internal(
  GalleryDownloadMonth.new,
  name: r'galleryDownloadMonthProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadMonthHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadMonth = Notifier<int>;
String _$galleryDownloadDayHash() =>
    r'6af43dadb836e1ee27acdde9ef2486f8d8aa23d5';

/// 下载日期筛选（0=不筛选）
///
/// Copied from [GalleryDownloadDay].
@ProviderFor(GalleryDownloadDay)
final galleryDownloadDayProvider =
    NotifierProvider<GalleryDownloadDay, int>.internal(
  GalleryDownloadDay.new,
  name: r'galleryDownloadDayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadDayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadDay = Notifier<int>;
String _$galleryDownloadSecondarySortHash() =>
    r'4976b19a9600f2bd61f443054dc41f8914603789';

/// 下载二次排序字段（空=不进行二次排序）
///
/// Copied from [GalleryDownloadSecondarySort].
@ProviderFor(GalleryDownloadSecondarySort)
final galleryDownloadSecondarySortProvider =
    NotifierProvider<GalleryDownloadSecondarySort, String>.internal(
  GalleryDownloadSecondarySort.new,
  name: r'galleryDownloadSecondarySortProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryDownloadSecondarySortHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryDownloadSecondarySort = Notifier<String>;
String _$galleryGridPreviewModeNotifierHash() =>
    r'c8a23aeed9c4b216f4b74af3334fbfbd7960e0ff';

/// 网格预览模式 Provider
///
/// Copied from [GalleryGridPreviewModeNotifier].
@ProviderFor(GalleryGridPreviewModeNotifier)
final galleryGridPreviewModeNotifierProvider = NotifierProvider<
    GalleryGridPreviewModeNotifier, GalleryGridPreviewMode>.internal(
  GalleryGridPreviewModeNotifier.new,
  name: r'galleryGridPreviewModeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryGridPreviewModeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryGridPreviewModeNotifier = Notifier<GalleryGridPreviewMode>;
String _$galleryTagAutoApplyEnabledHash() =>
    r'0000000000000000000000000000000000000000';

/// 标签自动套用开关（默认关闭）
///
/// Copied from [GalleryTagAutoApplyEnabled].
@ProviderFor(GalleryTagAutoApplyEnabled)
final galleryTagAutoApplyEnabledProvider =
    NotifierProvider<GalleryTagAutoApplyEnabled, bool>.internal(
  GalleryTagAutoApplyEnabled.new,
  name: r'galleryTagAutoApplyEnabledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$galleryTagAutoApplyEnabledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$GalleryTagAutoApplyEnabled = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
