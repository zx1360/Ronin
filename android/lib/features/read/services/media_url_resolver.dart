import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:torrid/core/services/network/api_client.dart';
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
          return await _resolveRedirect(requestUrl, source.extraHeaders);
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
      final status = e.response?.statusCode;
      if (status != null) throw _httpError(status);
      throw ApiClient.mapError(e);
    } on SocketException catch (e) {
      throw ApiException('无法连接媒体源，请检查网络', cause: e);
    } on TimeoutException catch (e) {
      throw ApiException('媒体源响应超时，请稍后重试', cause: e);
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

  static ApiException _httpError(int status) => ApiException(
    status == 429 ? '媒体源请求过多，请稍后重试' : '媒体源返回 HTTP $status',
    statusCode: status,
  );

  static Future<String> _resolveRedirect(
    String url,
    Map<String, String>? headers,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final requestHeaders = {'User-Agent': kUserAgent, ...?headers};
      requestHeaders.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode >= 400) throw _httpError(response.statusCode);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        final target = location == null ? null : Uri.tryParse(location.trim());
        if (target != null && target.toString().isNotEmpty) {
          final resolved = _mediaUrl(uri.resolveUri(target).toString());
          if (resolved != null) return resolved;
        }
        throw const ApiException('媒体源返回了无效的跳转地址');
      }
      final type = response.headers.contentType;
      if (response.statusCode == 200 &&
          (type?.primaryType == 'image' ||
              type?.primaryType == 'video' ||
              type?.mimeType == 'application/octet-stream')) {
        return url;
      }
      throw const ApiException('媒体源暂时无法提供内容，请更换来源或稍后重试');
    } finally {
      client.close(force: true);
    }
  }

  static String? _mediaUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
            uri.host.isNotEmpty &&
            (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri.toString()
        : null;
  }

  static Object? _jsonData(Response response) {
    final data = response.data;
    if (data is Map || data is List) return data;
    throw const ApiException('媒体源未返回资源数据，请更换来源或稍后重试');
  }

  static Future<String> _fetchFromJson(
    String url,
    String key,
    Map<String, String>? headers,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(headers: {'User-Agent': kUserAgent, ...?headers}),
    );
    final body = _jsonData(response);
    if (body is Map) {
      final value = _mediaUrl(body[key]);
      if (value != null) return value;

      final data = body['data'];
      if (data is Map) {
        final link = _mediaUrl(data['link']);
        if (link != null) return link;
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
    var current = _jsonData(response);
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
        if (index != null && index >= 0 && index < current.length) {
          current = current[index];
        } else {
          throw Exception('结果索引无效');
        }
      } else {
        throw Exception('响应格式异常');
      }
    }
    final mediaUrl = _mediaUrl(current);
    if (mediaUrl != null) return mediaUrl;
    throw Exception('无法获取有效的图片地址');
  }

  /// 流式下载到暂存文件，避免视频整体驻留内存。
  static Future<void> downloadFile(
    String url,
    String target, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    await _dio.download(
      url,
      target,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(minutes: 2),
        headers: {'User-Agent': kUserAgent, ...?headers},
      ),
    );
  }

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
