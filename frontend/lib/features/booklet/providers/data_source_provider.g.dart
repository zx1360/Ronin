// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_source_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$styleBoxHash() => r'86f47eecfc56e0491415fcd052775a3ce09837aa';

/// Style Box Provider - 提供 Style 数据的 Hive Box 访问
///
/// Copied from [styleBox].
@ProviderFor(styleBox)
final styleBoxProvider = AutoDisposeProvider<Box<Style>>.internal(
  styleBox,
  name: r'styleBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$styleBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StyleBoxRef = AutoDisposeProviderRef<Box<Style>>;
String _$recordBoxHash() => r'fc03ea57a54bf80295d800e2ad0aebe798e7d2fa';

/// Record Box Provider - 提供 Record 数据的 Hive Box 访问
///
/// Copied from [recordBox].
@ProviderFor(recordBox)
final recordBoxProvider = AutoDisposeProvider<Box<Record>>.internal(
  recordBox,
  name: r'recordBoxProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$recordBoxHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecordBoxRef = AutoDisposeProviderRef<Box<Record>>;
String _$styleStreamHash() => r'50bdb68d950ea127fc9c557856beafe121d3511c';

/// Style 数据流 - 监听 Box 变化，实时推送最新数据（已过滤墓碑）
///
/// Copied from [styleStream].
@ProviderFor(styleStream)
final styleStreamProvider = AutoDisposeStreamProvider<List<Style>>.internal(
  styleStream,
  name: r'styleStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$styleStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef StyleStreamRef = AutoDisposeStreamProviderRef<List<Style>>;
String _$recordStreamHash() => r'035a98f29cb5ed82dee55f16d4718abbbc6471fa';

/// Record 数据流 - 监听 Box 变化，实时推送最新数据（已过滤墓碑）
///
/// Copied from [recordStream].
@ProviderFor(recordStream)
final recordStreamProvider = AutoDisposeStreamProvider<List<Record>>.internal(
  recordStream,
  name: r'recordStreamProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$recordStreamHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef RecordStreamRef = AutoDisposeStreamProviderRef<List<Record>>;
String _$allStylesHash() => r'0ecf8046a2aa10bfedbc1fb0afb9c7ce1da4b00f';

/// 所有 Style 列表 - 同步访问接口
///
/// Copied from [allStyles].
@ProviderFor(allStyles)
final allStylesProvider = AutoDisposeProvider<List<Style>>.internal(
  allStyles,
  name: r'allStylesProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allStylesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllStylesRef = AutoDisposeProviderRef<List<Style>>;
String _$allRecordsHash() => r'38724d4d0f4f0085c6b63111f037c87b372df35f';

/// 所有 Record 列表 - 同步访问接口
///
/// Copied from [allRecords].
@ProviderFor(allRecords)
final allRecordsProvider = AutoDisposeProvider<List<Record>>.internal(
  allRecords,
  name: r'allRecordsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allRecordsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef AllRecordsRef = AutoDisposeProviderRef<List<Record>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
