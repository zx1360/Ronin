import 'dart:io';

import 'package:dio/dio.dart';
import 'package:torrid/features/read/models/random_media_models.dart';

// ────────────────────────────────────────────
// URL 解析与下载
// ────────────────────────────────────────────

class MediaUrlResolver {
  MediaUrlResolver._();

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 20)
    ..options.headers = {'User-Agent': kUserAgent};

  /// 根据源配置和用户参数获取实际资源 URL
  static Future<String> fetchMediaUrl(
    RandomMediaSource source, [
    Map<String, String> params = const {},
  ]) async {
    final requestUrl = _buildRequestUrl(source, params);
    try {
      switch (source.responseType) {
        case ApiResponseType.redirect302:
          return await _resolveRedirect(requestUrl);
        case ApiResponseType.json:
          if (source.jsonUrlPath != null) {
            return await _fetchFromJsonPath(
              requestUrl,
              source.jsonUrlPath!,
              params,
              source.extraHeaders,
            );
          }
          return await _fetchFromJson(
            requestUrl,
            source.jsonUrlKey ?? 'data',
            source.extraHeaders,
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

  /// 从源 URL 和用户参数构建完整请求 URL
  static String _buildRequestUrl(
    RandomMediaSource source,
    Map<String, String> params,
  ) {
    if (params.isEmpty) return source.apiUrl;
    final uri = Uri.parse(source.apiUrl);
    final allParams = Map<String, String>.from(uri.queryParameters);
    params.forEach((key, value) {
      if (value.isNotEmpty) allParams[key] = value;
    });
    return uri.replace(queryParameters: allParams).toString();
  }

  /// 使用 dart:io HttpClient 解析 302 重定向
  static Future<String> _resolveRedirect(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    client.badCertificateCallback = (_, __, ___) => true;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = false;
      request.headers.set('User-Agent', kUserAgent);
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          return location.startsWith('http')
              ? location
              : Uri.parse(url).resolve(location).toString();
        }
      }
      return url;
    } finally {
      client.close();
    }
  }

  /// 简单 JSON: response[key]
  static Future<String> _fetchFromJson(
    String url,
    String key,
    Map<String, String>? headers,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(headers: {'User-Agent': kUserAgent, ...?headers}),
    );
    if (response.data is Map) {
      final map = response.data as Map;
      final value = map[key];
      if (value is String && value.startsWith('http')) return value;

      // 兼容部分接口将链接放在 data.link 中（例如 tmini 视频接口）
      final data = map['data'];
      if (data is Map) {
        final link = data['link'];
        if (link is String && link.startsWith('http')) return link;
      }
    }
    throw Exception('无法从响应中获取有效的资源地址');
  }

  /// 嵌套 JSON: 按路径逐级提取, 支持 {paramKey} 占位符替换
  static Future<String> _fetchFromJsonPath(
    String url,
    List<String> path,
    Map<String, String> params,
    Map<String, String>? headers,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(headers: {'User-Agent': kUserAgent, ...?headers}),
    );
    dynamic current = response.data;
    for (var key in path) {
      if (key.startsWith('{') && key.endsWith('}')) {
        key = params[key.substring(1, key.length - 1)] ?? key;
      }
      if (current is Map) {
        if (!current.containsKey(key)) {
          throw Exception('响应中缺少字段: $key');
        }
        current = current[key];
      } else if (current is List) {
        if (current.isEmpty) throw Exception('没有找到匹配的结果');
        final index = int.tryParse(key);
        if (index != null && index < current.length) {
          current = current[index];
        } else {
          throw Exception('结果索引无效');
        }
      } else {
        throw Exception('响应格式异常');
      }
    }
    if (current is String && current.startsWith('http')) return current;
    throw Exception('无法获取有效的图片地址');
  }

  /// 下载资源字节数据
  static Future<List<int>> downloadBytes(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
        headers: {'User-Agent': kUserAgent, ...?headers},
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) throw Exception('下载数据为空');
    return data;
  }
}
