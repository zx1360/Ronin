import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/providers/network_config/network_config_provider.dart';

part 'api_client_provider.g.dart';

// apiClient网络请求客户端提供(管理)者.
//
// 配置来源唯一：由 [networkConfigManagerProvider] 派生。
// 仅当活跃配置或 API Key 实际变化时才重建 ApiClient，避免多余连接重建。
@Riverpod(keepAlive: true)
class ApiClientManager extends _$ApiClientManager {
  @override
  ApiClient build() {
    final activeConfig = ref.watch(
      networkConfigManagerProvider.select((s) => s.activeConfig),
    );
    final apiKey = ref.watch(
      networkConfigManagerProvider.select((s) => s.apiKey),
    );

    // 只有当 host 和 port 都非空时才构建有效 URL
    final baseUrl = (activeConfig != null && activeConfig.isValid)
        ? 'https://${activeConfig.host}:${activeConfig.port}'
        : '';
    return ApiClient(
      baseUrl: baseUrl,
      apiKey: apiKey.isEmpty ? null : apiKey,
    );
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
    final apiError = ApiClient.mapError(e);
    AppLogger().error("fetch '$path'出错: ${apiError.message}");
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
    final apiError = ApiClient.mapError(e);
    AppLogger().error("bytesFetcher '$path'出错: ${apiError.message}");
    return null;
  }
}

// send方法提供者(使用multipart form, 用于文件+JSON混合上传)
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
    final apiError = ApiClient.mapError(e);
    AppLogger().error("send出错: ${apiError.message}");
    return null;
  }
}

// jsonSender方法提供者(使用application/json body, 用于纯JSON请求)
@riverpod
Future<Response?> jsonSender(
  JsonSenderRef ref, {
  required String path,
  required Map<String, dynamic> data,
  CancelToken? cancelToken,
}) async {
  final apiClient = ref.watch(apiClientManagerProvider);
  try {
    final resp = await apiClient.postJson(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    return resp;
  } catch (e) {
    final apiError = ApiClient.mapError(e);
    AppLogger().error("jsonSend出错: ${apiError.message}");
    return null;
  }
}