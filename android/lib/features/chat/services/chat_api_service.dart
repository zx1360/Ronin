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

  const ChatStreamEvent({required this.type, this.content = '', this.error});

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    return ChatStreamEvent(
      type: (json['type'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      error: json['error'] as String?,
    );
  }
}

/// 一个可选的对话模型（由服务端下发，实时来自本机 Ollama 的已安装模型）。
class ChatModelOption {
  final String model;

  /// 本机是否已安装（由服务端判定，端上不自行比较名称）。
  final bool installed;

  /// 是否带视觉能力：不带的话发图片提问会答非所问。
  final bool vision;

  /// 服务端当前选定的模型。
  final bool current;

  const ChatModelOption({
    required this.model,
    required this.installed,
    required this.vision,
    required this.current,
  });
}

/// 服务端对话默认值与模型候选。
class ChatServerInfo {
  /// 当前选定的标注模型（即不逐次指定 model 时使用的那个）。
  final String model;

  /// 当前正在推理的模型（空 = 空闲）。
  final String activeModel;

  /// 可选的对话模型候选（服务端拿不到本机模型时为空）。
  final List<ChatModelOption> candidates;

  final int numCtx;
  final int keepAliveSeconds;
  final bool ready;

  const ChatServerInfo({
    required this.model,
    required this.activeModel,
    required this.candidates,
    required this.numCtx,
    required this.keepAliveSeconds,
    required this.ready,
  });

  factory ChatServerInfo.fromJson(Map<String, dynamic> data) => ChatServerInfo(
    model: data['model'] as String,
    activeModel: data['active_model'] as String,
    candidates: [
      for (final item in data['candidates'] as List)
        ChatModelOption(
          model: item['model'] as String,
          installed: item['installed'] as bool,
          vision: item['vision'] as bool,
          current: item['is_current'] as bool,
        ),
    ],
    numCtx: data['num_ctx'] as int,
    keepAliveSeconds: data['keep_alive_seconds'] as int,
    ready: data['ready'] as bool,
  );
}

/// 读取服务端默认值；不可达时由调用方降级展示。
final chatServerInfoProvider = FutureProvider<ChatServerInfo>((ref) async {
  final client = ref.watch(apiClientManagerProvider);
  try {
    final response = await client.get('/API/ai/chat/info');
    return ChatServerInfo.fromJson(response.data as Map<String, dynamic>);
  } catch (e) {
    throw ApiClient.mapError(e);
  }
});

class ChatApiService {
  ChatApiService(this._client);

  final ApiClient _client;

  /// 发起一次流式对话。
  Stream<ChatStreamEvent> chat({
    required List<Map<String, dynamic>> messages,
    required ChatOptions options,
    CancelToken? cancelToken,
  }) {
    return streamNdjsonEvents(
      _client,
      '/API/ai/chat',
      {
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
      failureLabel: '对话请求',
    );
  }
}

/// 把服务端的 NDJSON 流（每行一个事件）解成事件流；`/chat` 与 `/review` 共用。
///
/// 逐行解析以保证跨分片的半行不会被误解析；非 200 时读取响应体里的 `error`
/// 作为提示（服务端未启用 AI 能力等情况都会走到这里）。
Stream<ChatStreamEvent> streamNdjsonEvents(
  ApiClient client,
  String path,
  Map<String, dynamic> data, {
  CancelToken? cancelToken,
  required String failureLabel,
  Duration receiveTimeout = const Duration(minutes: 5),
}) async* {
  final Response<ResponseBody> response;
  try {
    response = await client.postStream(
      path,
      data: data,
      cancelToken: cancelToken,
      receiveTimeout: receiveTimeout,
    );
  } catch (e) {
    throw ApiClient.mapError(e);
  }

  final stream = response.data?.stream;
  if (stream == null) {
    throw ApiException('服务端未返回$failureLabel内容');
  }

  if (response.statusCode != 200) {
    final text = await _readAll(stream);
    throw ApiException(_errorMessage(text, response.statusCode, failureLabel));
  }

  yield* stream
      .cast<List<int>>()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty)
      .map(_decodeEvent);
}

ChatStreamEvent _decodeEvent(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is Map<String, dynamic>) {
      return ChatStreamEvent.fromJson(decoded);
    }
  } catch (_) {
    // 落单的非法行直接跳过，不让整轮生成失败
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

String _errorMessage(String body, int? statusCode, String failureLabel) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] != null) {
      return decoded['error'].toString();
    }
  } catch (_) {}
  final text = body.trim();
  if (text.isNotEmpty) return text;
  return '$failureLabel失败 (HTTP ${statusCode ?? '-'})';
}
