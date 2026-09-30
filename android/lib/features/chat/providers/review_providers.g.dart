// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$reviewPresetsControllerHash() =>
    r'5104433bf5e76259d3051272f4cf2a4398d1c26c';

/// 语气/角色预设：服务端权威 + 本地 Hive 镜像。
///
/// 读：先用镜像（离线可用），再异步与服务端对齐；
/// 写：整体推送到服务端，成功后才用服务端返回的列表刷新镜像。
///
/// Copied from [ReviewPresetsController].
@ProviderFor(ReviewPresetsController)
final reviewPresetsControllerProvider =
    NotifierProvider<ReviewPresetsController, ReviewPresetsState>.internal(
  ReviewPresetsController.new,
  name: r'reviewPresetsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reviewPresetsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReviewPresetsController = Notifier<ReviewPresetsState>;
String _$reviewHistoryControllerHash() =>
    r'ed34e1698ca5b37bfcafce5ca622a877c1556ea5';

/// 本地回顾历史（只存本机，不回传服务端）。
///
/// Copied from [ReviewHistoryController].
@ProviderFor(ReviewHistoryController)
final reviewHistoryControllerProvider =
    NotifierProvider<ReviewHistoryController, List<ReviewRecord>>.internal(
  ReviewHistoryController.new,
  name: r'reviewHistoryControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reviewHistoryControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReviewHistoryController = Notifier<List<ReviewRecord>>;
String _$reviewDraftControllerHash() =>
    r'5b4c9f157b3939f24ccbde82aee8a8a3ae7179ad';

/// 回顾生成控制器。
///
/// Copied from [ReviewDraftController].
@ProviderFor(ReviewDraftController)
final reviewDraftControllerProvider =
    NotifierProvider<ReviewDraftController, ReviewDraftState>.internal(
  ReviewDraftController.new,
  name: r'reviewDraftControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$reviewDraftControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ReviewDraftController = Notifier<ReviewDraftState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
