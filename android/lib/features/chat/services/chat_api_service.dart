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

/// 一个可选的对话模型（由服务端下发，实时来自本机 Ollama 的已安装模型）。
class ChatModelOption {
  final String model;
  final String label;

  /// 本机是否已安装（服务端判定，端上不再自己做名称比较）。
  final bool installed;

  /// 是否带视觉能力：不带的话发图片提问会答非所问，标注任务更不能选。
  final bool vision;

  /// 服务端当前生效的模型。
  final bool current;

  const ChatModelOption({
    required this.model,
    required this.label,
    required this.installed,
    required this.vision,
    required this.current,
  });
}

/// 服务端对话相关默认值（`/API/ai/status` 的 ollama 段 + `/API/ai/capabilities`）。
class ChatServerInfo {
  /// 当前生效的 VLM 标注模型。
  final String model;

  /// 当前正在推理的模型（空 = 空闲）。
  final String activeModel;

  /// 可选的对话模型候选。
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
}

/// 读取服务端默认值；不可达时由调用方降级展示。
final chatServerInfoProvider = FutureProvider<ChatServerInfo>((ref) async {
  final client = ref.watch(apiClientManagerProvider);
  try {
    final response = await client.get('/API/ai/status');
    final data = response.data as Map<String, dynamic>;
    final ollama = data['ollama'] as Map<String, dynamic>? ?? const {};
    final installed = [
      for (final item in (ollama['models'] as List? ?? const []))
        item.toString(),
    ];

    // 候选以服务端下发的执行者候选为准（服务端实时从本机 Ollama 取，
    // 用户自行 pull/rm 模型后无需改端上代码）；拿不到时退回状态里的两个候选。
    final candidates = await _fetchCandidates(client) ??
        _fallbackCandidates(ollama, installed);

    return ChatServerInfo(
      model: (ollama['model'] ?? '').toString(),
      activeModel: (ollama['active_model'] ?? '').toString(),
      candidates: candidates,
      numCtx: (ollama['num_ctx'] as num?)?.toInt() ?? 0,
      keepAliveSeconds:
          (ollama['keep_alive_default_seconds'] as num?)?.toInt() ?? 300,
      ready: ollama['model_ready'] == true,
    );
  } catch (e) {
    throw ApiClient.mapError(e);
  }
});

/// 取 VLM 能力的执行者候选；AI 表未初始化等情况下返回 null（设置页仍可用）。
Future<List<ChatModelOption>?> _fetchCandidates(ApiClient client) async {
  try {
    final response = await client.get('/API/ai/capabilities');
    final data = response.data as Map<String, dynamic>;
    final list = data['capabilities'] as List? ?? const [];
    for (final item in list) {
      final capability = item as Map<String, dynamic>;
      if (capability['capability'] != 'vlm') continue;
      final raw = capability['executor_candidates'] as List? ?? const [];
      return [
        for (final candidate in raw)
          ChatModelOption(
            model: (candidate['model'] ?? '').toString(),
            label: (candidate['label'] ?? candidate['model'] ?? '').toString(),
            installed: candidate['installed'] == true,
            vision: candidate['vision'] == true,
            current: candidate['is_current'] == true,
          ),
      ];
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// 能力清单不可用时的兜底候选（老版本服务端的 model_default / model_alt）。
List<ChatModelOption> _fallbackCandidates(
  Map<String, dynamic> ollama,
  List<String> installed,
) {
  final current = (ollama['model'] ?? '').toString();
  final entries = <List<String>>[
    ['标准版', (ollama['model_default'] ?? '').toString()],
    ['无审查版', (ollama['model_alt'] ?? '').toString()],
  ];
  final seen = <String>{};
  final out = <ChatModelOption>[];
  for (final entry in entries) {
    final name = entry[1];
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    out.add(ChatModelOption(
      model: name,
      label: entry[0],
      // 模型名大小写不敏感（配置里是 :4B，Ollama 里存的是 :4b）
      installed: _installedIn(installed, name),
      vision: true,
      current: name.toLowerCase() == current.toLowerCase(),
    ));
  }
  return out;
}

/// 判断模型是否在已安装列表里（容忍大小写与 tag 差异）。
bool _installedIn(List<String> installed, String model) {
  final target = model.toLowerCase();
  if (target.isEmpty) return false;
  for (final item in installed) {
    final name = item.toLowerCase();
    if (name == target || name.startsWith('$target:')) return true;
  }
  return false;
}

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
