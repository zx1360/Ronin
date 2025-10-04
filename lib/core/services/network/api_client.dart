import 'dart:io';

import 'package:dio/dio.dart';

// TODO: 单例或依赖注入避免频繁创销, (注意baseUrl也许会变的问题.)
class ApiClient {  
  final Dio _dio = Dio();
  final String baseUrl;

  ApiClient({required this.baseUrl}) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 4);
    _dio.options.receiveTimeout = const Duration(seconds: 6);
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
