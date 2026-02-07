import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

part 'api_client_provider.g.dart';

// apiClient网络请求客户端提供(管理)者.
@Riverpod(keepAlive: true)
class ApiClientManager extends _$ApiClientManager {
  @override
  ApiClient build() {
    final prefs = PrefsService().prefs;
    final host = prefs.getString("PC_HOST") ?? "";
    final port = prefs.getString("PC_PORT") ?? "";
    final apiKey = prefs.getString("API_KEY");
    // 只有当 host 和 port 都非空时才构建有效 URL
    final baseUrl = (host.isNotEmpty && port.isNotEmpty)
        ? "http://$host:$port"
        : "";
    return ApiClient(baseUrl: baseUrl, apiKey: apiKey);
  }

  String get address => state.baseUrl;

  Future<void> setAddr({required String host, required String port}) async {
    final prefs = PrefsService().prefs;
    await prefs.setString("PC_HOST", host);
    await prefs.setString("PC_PORT", port);
    final apiKey = prefs.getString("API_KEY");
    state = ApiClient(baseUrl: "http://$host:$port", apiKey: apiKey);
  }

  Future<void> setApiKey(String apiKey) async {
    final prefs = PrefsService().prefs;
    await prefs.setString("API_KEY", apiKey);
    // 重新构建 ApiClient 以应用新的 API Key
    final host = prefs.getString("PC_HOST") ?? "";
    final port = prefs.getString("PC_PORT") ?? "";
    final baseUrl = (host.isNotEmpty && port.isNotEmpty)
        ? "http://$host:$port"
        : "";
    state = ApiClient(baseUrl: baseUrl, apiKey: apiKey.isNotEmpty ? apiKey : null);
  }
}

// fetch方法提供者
@riverpod
Future<Response?> fetcher(
  FetcherRef ref, {
  required String path,
  Map<String, dynamic>? params,
  CancelToken? cancelToken,
  ProgressCallback? onReceiveProgress,
}) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  try {
    final resp = await apiClient.get(
      path,
      queryParams: params,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return resp;
  } catch (e) {
    AppLogger().error("fetch'$path'出错: $e");
    return null;
  }
}

/// bytesFetcher方法提供者，专门用于获取二进制数据
@riverpod
Future<Response<Uint8List>?> bytesFetcher(
  BytesFetcherRef ref, {
  required String path,
  Map<String, dynamic>? params,
  CancelToken? cancelToken,
  ProgressCallback? onReceiveProgress,
}) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  try {
    final resp = await apiClient.getBinary(
      path,
      queryParams: params,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return resp;
  } catch (e) {
    AppLogger().error("bytesFetcher '$path'出错: $e");
    return null;
  }
}

// send方法提供者
@riverpod
Future<Response?> sender(
  SenderRef ref, {
  required String path,
  Map<String, dynamic>? jsonData,
  List<File>? files,
  CancelToken? cancelToken,
  ProgressCallback? onSendProgress,
}) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  try {
    final resp = await apiClient.post(
      path,
      jsonData: jsonData,
      files: files,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    return resp;
  } catch (e) {
    AppLogger().error("send出错: $e");
    return null;
  }
}