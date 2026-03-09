import 'package:dio/dio.dart';

/// API 响应类型
enum ApiResponseType {
  /// HTTP 302 重定向到实际资源地址
  redirect302,

  /// JSON 响应中包含实际资源 URL
  json,
}

/// 随机媒体 API 源定义
class RandomMediaSource {
  final String label;
  final String apiUrl;
  final ApiResponseType responseType;

  /// JSON 响应时，提取 URL 所用的 key
  final String? jsonUrlKey;

  const RandomMediaSource({
    required this.label,
    required this.apiUrl,
    required this.responseType,
    this.jsonUrlKey,
  });
}

// ────────────────────────────────────────────
// API 源列表
// ────────────────────────────────────────────

/// 图片 API 源（10 个）
const kImageApiSources = <RandomMediaSource>[
  // ── random-api.czl.net（302 重定向）──
  RandomMediaSource(
    label: '全部图片 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/all',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: '普通图片 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/normal',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: 'AI 图片 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/ai',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: '二次元 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/ecy',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: '网站背景图 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/czlwb',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: '风景 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/fj',
    responseType: ApiResponseType.redirect302,
  ),
  RandomMediaSource(
    label: '美女 (czl)',
    apiUrl: 'https://random-api.czl.net/pic/truegirl',
    responseType: ApiResponseType.redirect302,
  ),
  // ── xxapi.cn（JSON 响应）──
  RandomMediaSource(
    label: '4K 二次元 (xxapi)',
    apiUrl: 'https://v2.xxapi.cn/api/random4kPic?type=acg&return=json',
    responseType: ApiResponseType.json,
    jsonUrlKey: 'data',
  ),
  RandomMediaSource(
    label: '4K 风景壁纸 (xxapi)',
    apiUrl: 'https://v2.xxapi.cn/api/random4kPic?type=wallpaper&return=json',
    responseType: ApiResponseType.json,
    jsonUrlKey: 'data',
  ),
];

/// 视频 API 源（1 个）
const kVideoApiSources = <RandomMediaSource>[
  // ── random-api.czl.net（302 重定向）──
  RandomMediaSource(
    label: '抖音艺术 (czl)',
    apiUrl: 'https://random-api.czl.net/video/dy-art',
    responseType: ApiResponseType.redirect302,
  ),
];

// ────────────────────────────────────────────
// URL 解析与下载
// ────────────────────────────────────────────

class MediaUrlResolver {
  MediaUrlResolver._();

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 20);

  /// 根据 API 源配置获取实际资源 URL
  static Future<String> fetchMediaUrl(RandomMediaSource source) async {
    try {
      switch (source.responseType) {
        case ApiResponseType.redirect302:
          return await _resolveRedirect(source.apiUrl);
        case ApiResponseType.json:
          return await _fetchFromJson(
            source.apiUrl,
            source.jsonUrlKey ?? 'data',
          );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('连接超时，请检查网络');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('接收数据超时');
      }
      if (e.response?.statusCode != null) {
        throw Exception('服务器错误 (${e.response!.statusCode})');
      }
      throw Exception('网络请求失败');
    }
  }

  /// 解析 302 重定向链，返回最终资源 URL
  static Future<String> _resolveRedirect(String url) async {
    String current = url;
    for (int i = 0; i < 5; i++) {
      final response = await _dio.get(
        current,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode != null && response.statusCode! >= 300) {
        final location = response.headers.value('location');
        if (location == null) return current;
        current = location.startsWith('http')
            ? location
            : Uri.parse(current).resolve(location).toString();
      } else {
        return current;
      }
    }
    return current;
  }

  /// 从 JSON 响应中提取资源 URL
  static Future<String> _fetchFromJson(String url, String key) async {
    final response = await _dio.get(url);
    if (response.data is Map) {
      final value = (response.data as Map)[key];
      if (value is String && value.startsWith('http')) return value;
    }
    throw Exception('无法从响应中获取有效的资源地址');
  }

  /// 下载资源字节数据
  static Future<List<int>> downloadBytes(String url) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('下载数据为空');
    }
    return data;
  }
}
