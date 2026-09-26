import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/chat/models/chat_options.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

/// 服务端对话接口（`POST /API/ai/chat`，NDJSON 流）。
final chatApiProvider = Provider<ChatApiService>((ref) {
  return ChatApiService(ref.watch(apiClientManagerProvider));
});

/// 一条流式事件。
class ChatStreamEvent {
  /// delta / thinking / done / error
  final String type;
  final String content;
  final String? error;

  const ChatStreamEvent({
    required this.type,
    this.content = '',
    this.error,
  });

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      type: (json['type'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      error: json['error'] as String?,
    );
  }
}

/// 服务端对话相关默认值（`/API/ai/status` 的 ollama 段）。
class ChatServerInfo {
  /// 当前生效的 VLM 标注模型。
  final String model;

  /// 两个候选：标准版 / 无审查版。
  final String modelDefault;
  final String modelAlt;

  /// 当前正在推理的模型（空 = 空闲）。
  final String activeModel;

  /// 已安装的模型列表。
  final List<String> installed;
  final int numCtx;
  final int keepAliveSeconds;
  final bool ready;

  const ChatServerInfo({
    required this.model,
    required this.modelDefault,
    required this.modelAlt,
    required this.activeModel,
    required this.installed,
    required this.numCtx,
    required this.keepAliveSeconds,
    required this.ready,
  });

  /// 模型是否已安装（容忍 tag 差异）。
  bool isInstalled(String model) {
    for (final item in installed) {
      if (item == model || item.startsWith('$model:')) return true;
    }
    return false;
  }
}

/// 读取服务端默认值；不可达时由调用方降级展示。
final chatServerInfoProvider = FutureProvider<ChatServerInfo>((ref) async {
  final client = ref.watch(apiClientManagerProvider);
  try {
    final response = await client.get('/API/ai/status');
    final data = response.data as Map<String, dynamic>;
    final ollama = data['ollama'] as Map<String, dynamic>? ?? const {};
    return ChatServerInfo(
      model: (ollama['model'] ?? '').toString(),
      modelDefault: (ollama['model_default'] ?? '').toString(),
      modelAlt: (ollama['model_alt'] ?? '').toString(),
      activeModel: (ollama['active_model'] ?? '').toString(),
      installed: [
        for (final item in (ollama['models'] as List? ?? const []))
          item.toString(),
      ],
      numCtx: (ollama['num_ctx'] as num?)?.toInt() ?? 0,
      keepAliveSeconds:
          (ollama['keep_alive_default_seconds'] as num?)?.toInt() ?? 300,
      ready: ollama['model_ready'] == true,
    );
  } catch (e) {
    throw ApiClient.mapError(e);
  }
});

class ChatApiService {
  ChatApiService(this._client);

  final ApiClient _client;

  /// 发起一次流式对话。
  ///
  /// 逐条解析服务端下发的 NDJSON；非 200 时读取响应体里的 `error` 作为提示。
  Stream<ChatStreamEvent> chat({
    required List<Map<String, dynamic>> messages,
    required ChatOptions options,
    CancelToken? cancelToken,
  }) async* {
    final Response<ResponseBody> response;
    try {
      response = await _client.postStream(
        '/API/ai/chat',
        data: {
          'messages': messages,
          if (options.model.isNotEmpty) 'model': options.model,
          if (options.numCtx > 0) 'num_ctx': options.numCtx,
          'think': options.think,
          'temperature': options.temperature,
          'keep_alive_seconds': options.customKeepAlive
              ? options.keepAliveSeconds
              : null,
        },
        cancelToken: cancelToken,
      );
    } catch (e) {
      throw ApiClient.mapError(e);
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw const ApiException('服务端未返回对话内容');
    }

    if (response.statusCode != 200) {
      final text = await _readAll(stream);
      throw ApiException(_errorMessage(text, response.statusCode));
    }

    // 服务端按行下发 JSON，用 LineSplitter 保证跨分片的半行不会被误解析。
    yield* stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map(_decode);
  }

  ChatStreamEvent _decode(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        return ChatStreamEvent.fromJson(decoded);
      }
    } catch (_) {
      // 落单的非法行直接跳过，不让整轮对话失败
    }
    return const ChatStreamEvent(type: 'ignore');
  }

  Future<String> _readAll(Stream<List<int>> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String _errorMessage(String body, int? statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    final text = body.trim();
    if (text.isNotEmpty) return text;
    return '对话请求失败 (HTTP ${statusCode ?? '-'})';
  }
}
