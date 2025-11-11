import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client.dart';
import 'package:torrid/providers/server_connect/server_conn_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';

part 'api_client_provider.g.dart';

// apiClient网络请求客户端提供(管理)者.
@Riverpod(keepAlive: true)
class ApiClientManager extends _$ApiClientManager {
  @override
  ApiClient build() {
    final conf = ref.read(serverConnectorProvider);
    print(conf);
    return ApiClient(baseUrl: "http://${conf['host_']}:${conf['port_']}");
  }

  String get address => state.baseUrl;
  // 切换baseUrl为云服务器地址.
  void switchToNetServer() {
    final conf = ref.read(serverConnectorProvider);
    print("__TONet, http://${conf['host_']}:${conf['port_']}");
    state = ApiClient(baseUrl: "http://${conf['host_']}:${conf['port_']}");
    print(state.baseUrl);
  }

  // 切换baseUrl为PC地址.
  void switchToPCServer() {
    final conf = ref.read(serverConnectorProvider);
    print("__TOPC, http://${conf['host']}:${conf['port']}");
    state = ApiClient(baseUrl: "http://${conf['host']}:${conf['port']}");
    print(state.baseUrl);
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
  print("__fetcher: ${path}");
  print(apiClient.baseUrl);
  try {
    final resp = await apiClient.get(
      path,
      queryParams: params,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
    return resp;
  } catch (e) {
    AppLogger().error("fetch出错: $e");
    ref.read(apiClientManagerProvider.notifier).switchToNetServer();
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
    ref.read(apiClientManagerProvider.notifier).switchToNetServer();
    return null;
  }
}
