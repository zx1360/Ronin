/// 对话的可调参数与服务端默认值。
library;

import 'package:torrid/core/services/storage/prefs_service.dart';

/// 对话设置（本地持久化，逐次请求下发给后端）。
class ChatOptions {
  /// 上下文窗口（token）；0 表示跟随服务端 OLLAMA_VLM_CTX。
  final int numCtx;

  /// 深度思考（思考链会先输出再给答案）。
  final bool think;

  /// 采样温度。
  final double temperature;

  /// 是否使用自定义的模型卸载超时（false = 后端默认值）。
  final bool customKeepAlive;

  /// 自定义模型卸载超时（秒）；0 表示回答完立即卸载。
  final int keepAliveSeconds;

  /// 对话使用的模型；空串表示跟随后端当前生效的模型。
  final String model;

  const ChatOptions({
    this.numCtx = 0,
    this.think = false,
    this.temperature = 0.7,
    this.customKeepAlive = false,
    this.keepAliveSeconds = 300,
    this.model = '',
  });

  /// 可选上下文档位（与服务端 2048~262144 的取值区间一致）。
  static const List<int> ctxChoices = [0, 8192, 16384, 32768, 65536];

  ChatOptions copyWith({
    int? numCtx,
    bool? think,
    double? temperature,
    bool? customKeepAlive,
    int? keepAliveSeconds,
    String? model,
  }) {
    return ChatOptions(
      numCtx: numCtx ?? this.numCtx,
      think: think ?? this.think,
      temperature: temperature ?? this.temperature,
      customKeepAlive: customKeepAlive ?? this.customKeepAlive,
      keepAliveSeconds: keepAliveSeconds ?? this.keepAliveSeconds,
      model: model ?? this.model,
    );
  }
}

/// 对话设置的持久化键（SharedPreferences）。
class ChatPrefsKeys {
  static const String numCtx = 'chat_num_ctx';
  static const String think = 'chat_think';
  static const String temperatureX10 = 'chat_temperature_x10';
  static const String customKeepAlive = 'chat_keep_alive_custom';
  static const String keepAliveSeconds = 'chat_keep_alive_seconds';
  static const String model = 'chat_model';
}

/// 从本地读取对话设置（缺省即默认值）。
ChatOptions loadChatOptions() {
  final prefs = PrefsService().prefs;
  return ChatOptions(
    numCtx: prefs.getInt(ChatPrefsKeys.numCtx) ?? 0,
    think: prefs.getBool(ChatPrefsKeys.think) ?? false,
    // 以 0.1 为步长存整数，避免浮点持久化的精度烦恼
    temperature:
        (prefs.getInt(ChatPrefsKeys.temperatureX10) ?? 7).clamp(0, 20) / 10,
    customKeepAlive: prefs.getBool(ChatPrefsKeys.customKeepAlive) ?? false,
    keepAliveSeconds: prefs.getInt(ChatPrefsKeys.keepAliveSeconds) ?? 300,
    model: prefs.getString(ChatPrefsKeys.model) ?? '',
  );
}

/// 持久化对话设置。
Future<void> saveChatOptions(ChatOptions options) async {
  final prefs = PrefsService().prefs;
  await prefs.setInt(ChatPrefsKeys.numCtx, options.numCtx);
  await prefs.setBool(ChatPrefsKeys.think, options.think);
  await prefs.setInt(
    ChatPrefsKeys.temperatureX10,
    (options.temperature * 10).round(),
  );
  await prefs.setBool(ChatPrefsKeys.customKeepAlive, options.customKeepAlive);
  await prefs.setInt(ChatPrefsKeys.keepAliveSeconds, options.keepAliveSeconds);
  await prefs.setString(ChatPrefsKeys.model, options.model);
}
