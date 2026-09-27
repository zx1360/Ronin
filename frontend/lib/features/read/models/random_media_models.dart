/// 模拟常规移动浏览器的 User-Agent
const String kUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36';

enum ApiResponseType { redirect302, json }

/// 可选参数的单项
class ApiParamOption {
  final String value;
  final String label;
  const ApiParamOption(this.value, this.label);
}

/// API 可选参数
class ApiParam {
  final String key;
  final String label;

  /// null → 文本输入框, 非 null → 下拉选择
  final List<ApiParamOption>? options;
  final String defaultValue;
  final String? hint;

  const ApiParam({
    required this.key,
    required this.label,
    this.options,
    this.defaultValue = '',
    this.hint,
  });

  bool get isTextInput => options == null;
}

/// 单个 API 源
class RandomMediaSource {
  final String label;
  final String apiUrl;
  final ApiResponseType responseType;

  /// 简单 JSON 提取: response[key]
  final String? jsonUrlKey;

  /// 嵌套 JSON 提取: 按路径逐级索引, 支持 {paramKey} 占位符
  final List<String>? jsonUrlPath;

  final List<ApiParam> params;

  /// 加载 / 下载图片时需要的额外请求头
  final Map<String, String>? extraHeaders;

  const RandomMediaSource({
    required this.label,
    required this.apiUrl,
    required this.responseType,
    this.jsonUrlKey,
    this.jsonUrlPath,
    this.params = const [],
    this.extraHeaders,
  });
}

/// API 源分组（同一站点的多个端点）
class MediaApiGroup {
  final String id;
  final String name;
  final List<RandomMediaSource> sources;

  const MediaApiGroup({
    required this.id,
    required this.name,
    required this.sources,
  });
}
