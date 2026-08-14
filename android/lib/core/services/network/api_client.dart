import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:torrid/core/services/network/cert_trust.dart';

/// 统一 API 异常
///
/// 将底层 [DioException] 归一化为对用户友好的消息，并保留原始错误。
/// 所有网络层错误都应通过 [ApiClient.mapError] 映射为 [ApiException]，
/// 避免 UI 直接处理底层协议细节。
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.cause});

  @override
  String toString() => message;
}

// 通过riverpod提供此实例以使同一时间只有一个Dio实例.
class ApiClient {
  final Dio _dio = Dio();
  final String baseUrl;
  final String? apiKey;

  ApiClient({required this.baseUrl, this.apiKey}) {
    // 只有当 baseUrl 非空时才设置，避免无效 URL 错误
    if (baseUrl.isNotEmpty) {
      _dio.options.baseUrl = baseUrl;
    }
    _dio.options.connectTimeout = const Duration(seconds: 8);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    // 配置 Dio 信任自签证书
    _dio.httpClientAdapter = CertTrust.createAdapter();
    // 添加拦截器以在每个请求中添加 X-API-Key 头
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (apiKey != null && apiKey!.isNotEmpty) {
            options.headers['X-API-Key'] = apiKey;
          }
          handler.next(options);
        },
      ),
    );
    // 统一请求生命周期：幂等 GET 请求在连接类错误时自动重试
    _dio.interceptors.add(_RetryInterceptor(_dio));
  }

  /// 将底层异常归一化为 [ApiException]
  ///
  /// 非 [DioException] 的错误原样包装，保证调用方始终拿到可读信息。
  static ApiException mapError(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
            '连接超时，请检查服务器地址或网络',
            cause: error,
          );
        case DioExceptionType.connectionError:
          return ApiException(
            '无法连接服务器，请检查地址或网络',
            cause: error,
          );
        case DioExceptionType.badCertificate:
          return ApiException('证书校验失败', cause: error);
        case DioExceptionType.badResponse:
          return ApiException(
            '服务器响应异常 (HTTP ${error.response?.statusCode ?? '-'})',
            statusCode: error.response?.statusCode,
            cause: error,
          );
        case DioExceptionType.cancel:
          return const ApiException('请求已取消');
        case DioExceptionType.unknown:
          return ApiException(
            error.message ?? '网络请求失败',
            cause: error,
          );
      }
    }
    return ApiException(error.toString(), cause: error);
  }

  /// 获取请求头（包含 API Key，用于第三方库如 CachedNetworkImage）
  Map<String, String> get headers {
    if (apiKey != null && apiKey!.isNotEmpty) {
      return {'X-API-Key': apiKey!};
    }
    return {};
  }

  // GET请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get(
      path,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// GET请求，专门用于获取二进制数据（如图片）
  Future<Response<Uint8List>> getBinary(
    String path, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<Uint8List>(
      path,
      queryParameters: queryParams,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  /// POST请求，直接发送 JSON body (Content-Type: application/json)
  Future<Response> postJson(
    String path, {
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    return _dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: Options(contentType: 'application/json'),
    );
  }

  /// PUT请求，直接发送 JSON body
  Future<Response> putJson(
    String path, {
    required Map<String, dynamic> data,
    CancelToken? cancelToken,
  }) async {
    return _dio.put(
      path,
      data: data,
      cancelToken: cancelToken,
      options: Options(contentType: 'application/json'),
    );
  }

  // POST请求, 可以上传json数据和文件.
  Future<Response> post(
    String path, {
    Map<String, dynamic>? jsonData,
    List<File>? files,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData();
    // 加入json数据
    if (jsonData != null) {
      jsonData.forEach((key, value) {
        formData.fields.add(MapEntry(key, value));
      });
    }
    // 加入文件数据
    if (files != null) {
      for (var file in files) {
        formData.files.add(
          MapEntry(
            "files",
            await MultipartFile.fromFile(
              file.path,
              filename: file.path.split("/").last,
            ),
          ),
        );
      }
    }
    // 发送请求
    return _dio.post(
      path,
      data: formData,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }
}

/// GET 请求自动重试拦截器
///
/// 仅对幂等的 GET 请求在连接类错误（超时/连接失败）时自动重试，
/// 不重试业务错误（4xx/5xx）与主动取消，避免产生副作用或重复请求。
class _RetryInterceptor extends Interceptor {
  static const int _maxAttempts = 2; // 首次请求 + 1 次重试
  static const String _retryCountKey = '__retryCount';

  final Dio _dio;

  _RetryInterceptor(this._dio);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    final canRetry = options.method == 'GET' &&
        _isConnectionError(err.type) &&
        _attempts(options) < _maxAttempts;

    if (!canRetry) {
      handler.next(err);
      return;
    }

    options.extra[_retryCountKey] = _attempts(options) + 1;
    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } catch (e) {
      handler.next(e is DioException ? e : err);
    }
  }

  bool _isConnectionError(DioExceptionType type) {
    return type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError;
  }

  int _attempts(RequestOptions options) => options.extra[_retryCountKey] ?? 0;
}