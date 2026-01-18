// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay_notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$essayServiceHash() => r'eaa0e41810fddcc59eeb12213b6d60763682036e';

/// Essay 模块的核心服务
///
/// 提供以下功能：
/// - 随笔 CRUD 操作
/// - 标签管理
/// - 年度/月度统计更新
/// - 数据同步与备份
///
/// Copied from [EssayService].
@ProviderFor(EssayService)
final essayServiceProvider =
    AutoDisposeNotifierProvider<EssayService, EssayRepository>.internal(
  EssayService.new,
  name: r'essayServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EssayService = AutoDisposeNotifier<EssayRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
