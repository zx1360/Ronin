// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 对话设置（本地持久化）。

@ProviderFor(ChatOptionsController)
final chatOptionsControllerProvider = ChatOptionsControllerProvider._();

/// 对话设置（本地持久化）。
final class ChatOptionsControllerProvider
    extends $NotifierProvider<ChatOptionsController, ChatOptions> {
  /// 对话设置（本地持久化）。
  ChatOptionsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatOptionsControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatOptionsControllerHash();

  @$internal
  @override
  ChatOptionsController create() => ChatOptionsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatOptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatOptions>(value),
    );
  }
}

String _$chatOptionsControllerHash() =>
    r'fda0f914bf06476148e6cc8db0a9d9735e46d701';

/// 对话设置（本地持久化）。

abstract class _$ChatOptionsController extends $Notifier<ChatOptions> {
  ChatOptions build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChatOptions, ChatOptions>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatOptions, ChatOptions>,
              ChatOptions,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 聊天控制器：本地会话读写 + 流式请求编排。
///
/// 流式增量只更新内存，用户消息和一轮结束的回复分别落库。

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// 聊天控制器：本地会话读写 + 流式请求编排。
///
/// 流式增量只更新内存，用户消息和一轮结束的回复分别落库。
final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, ChatState> {
  /// 聊天控制器：本地会话读写 + 流式请求编排。
  ///
  /// 流式增量只更新内存，用户消息和一轮结束的回复分别落库。
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();
}

String _$chatControllerHash() => r'00dcfb043a77b4d7ab06a3c45b380d36e4f715e2';

/// 聊天控制器：本地会话读写 + 流式请求编排。
///
/// 流式增量只更新内存，用户消息和一轮结束的回复分别落库。

abstract class _$ChatController extends $AsyncNotifier<ChatState> {
  FutureOr<ChatState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ChatState>, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ChatState>, ChatState>,
              AsyncValue<ChatState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
