// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'box_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$summaryBoxHash() => r'43b7f357b01ac8e090c1b3c0e7b38be52fcb2796';

/// 年度统计信息的 Hive Box
///
/// Copied from [summaryBox].
@ProviderFor(summaryBox)
final summaryBoxProvider = AutoDisposeProvider<Box<YearSummary>>.internal(
  summaryBox,
  name: r'summaryBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$summaryBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SummaryBoxRef = AutoDisposeProviderRef<Box<YearSummary>>;
String _$summaryStreamHash() => r'e2862993b5b2f345debfcf9ccfec59d11112e261';

/// 年度统计信息的响应式流（已过滤墓碑）
///
/// 使用 yield 手动触发一次以读取初始数据，之后监听 box 变化。
///
/// Copied from [summaryStream].
@ProviderFor(summaryStream)
final summaryStreamProvider =
    AutoDisposeStreamProvider<List<YearSummary>>.internal(
  summaryStream,
  name: r'summaryStreamProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$summaryStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SummaryStreamRef = AutoDisposeStreamProviderRef<List<YearSummary>>;
String _$essayBoxHash() => r'4c04d29c307c031ea1b3063d5c519218a95d9136';

/// 随笔数据的 Hive Box
///
/// Copied from [essayBox].
@ProviderFor(essayBox)
final essayBoxProvider = AutoDisposeProvider<Box<Essay>>.internal(
  essayBox,
  name: r'essayBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EssayBoxRef = AutoDisposeProviderRef<Box<Essay>>;
String _$essayStreamHash() => r'9589797a234d0cddb5a85b13180b2fa57ac5a3f1';

/// 随笔数据的响应式流（已过滤墓碑）
///
/// Copied from [essayStream].
@ProviderFor(essayStream)
final essayStreamProvider = AutoDisposeStreamProvider<List<Essay>>.internal(
  essayStream,
  name: r'essayStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EssayStreamRef = AutoDisposeStreamProviderRef<List<Essay>>;
String _$labelBoxHash() => r'9344185ac11e932f41f54c4341dd772cdf14aa06';

/// 标签数据的 Hive Box
///
/// Copied from [labelBox].
@ProviderFor(labelBox)
final labelBoxProvider = AutoDisposeProvider<Box<Label>>.internal(
  labelBox,
  name: r'labelBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$labelBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LabelBoxRef = AutoDisposeProviderRef<Box<Label>>;
String _$labelStreamHash() => r'83cf3fda722f5c997d0bbc92d07f699726cbf41d';

/// 标签数据的响应式流（已过滤墓碑）
///
/// Copied from [labelStream].
@ProviderFor(labelStream)
final labelStreamProvider = AutoDisposeStreamProvider<List<Label>>.internal(
  labelStream,
  name: r'labelStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$labelStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef LabelStreamRef = AutoDisposeStreamProviderRef<List<Label>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
