import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client.dart';
import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';

part 'api_client_provider.g.dart';

// apiClient网络请求客户端提供(管理)者.
@riverpod
class ApiClientManager extends _$ApiClientManager {
  @override
  ApiClient build() {
    final prefs = PrefsService().prefs;
    final pcIp = prefs.getString("PC_IP");
    final pcPort = prefs.getString("PC_PORT");
    _currentIp = pcIp ?? "";
    _currentPort = pcPort ?? "";
    return ApiClient(baseUrl: "http://$pcIp:$pcPort");
  }

  late String _currentIp;
  late String _currentPort;
  String get ip => _currentIp;
  String get port => _currentPort;
  String get address => "http://$_currentIp:$_currentPort";

  Future<void> setAddress({required String ip, required String port}) async {
    final prefs = PrefsService().prefs;
    await prefs.setString("PC_IP", ip);
    await prefs.setString("PC_PORT", port);
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
    AppLogger().error("fetch出错: $e");
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
