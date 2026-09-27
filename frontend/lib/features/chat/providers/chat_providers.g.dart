// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatOptionsControllerHash() =>
    r'fda0f914bf06476148e6cc8db0a9d9735e46d701';

/// 对话设置（本地持久化）。
///
/// Copied from [ChatOptionsController].
@ProviderFor(ChatOptionsController)
final chatOptionsControllerProvider =
    NotifierProvider<ChatOptionsController, ChatOptions>.internal(
  ChatOptionsController.new,
  name: r'chatOptionsControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatOptionsControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatOptionsController = Notifier<ChatOptions>;
String _$chatControllerHash() => r'58c91e46caefd68ea327e92a53f273f52b7c6f4e';

/// 聊天控制器：本地会话读写 + 流式请求编排。
///
/// 流式增量只更新内存状态，一轮结束（或失败）时才落库——每个 token 都写一次
/// Hive 既慢又无意义。
///
/// Copied from [ChatController].
@ProviderFor(ChatController)
final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>.internal(
  ChatController.new,
  name: r'chatControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatController = Notifier<ChatState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
