import 'dart:io';

import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

import 'package:torrid/core/services/network/api_client.dart';
import 'package:dio/dio.dart';

import 'package:torrid/shared/models/network_status.dart';


// TODO: 实际上页面创建status等会传三层到达Dio, 也许麻烦了, 但也留了设置全局拦截器, 页面拦截器的空间.
class ApiclientHandler {
  // GET请求封装
  static Future<Response?> fetch({
    required String path,
    NetworkStatus? status,
    Map<String, dynamic> params = const {},
  }) async {
    final pcIP = (await PrefsService.prefs).getString("PC_IP");
    final apiClient = ApiClient(baseUrl: "http://$pcIP:4215");
    try {
      final resp = await apiClient.get(
        path,
        queryParams: params,
        cancelToken: status?.cancelToken,
        onReceiveProgress: status?.progressCallback,
      );
      return resp;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger().info("fetch`${apiClient.baseUrl}$path`: 请求取消.");
      } else {
        AppLogger().info("fetch`${apiClient.baseUrl}$path`: 请求失败.");
      }
    } catch (e) {
      throw Exception("fetch`${apiClient.baseUrl}$path`: 出错: $e");
    }
    return null;
  }

  // POST封装
  static Future<Response?> send({
    required String path,
    NetworkStatus? status,
    Map<String, dynamic> jsonData = const {},
    List<File> files = const[],
  }) async {
    final pcIP = (await PrefsService.prefs).getString("PC_IP");
    final apiClient = ApiClient(baseUrl: "http://$pcIP:4215");
    try {
      final resp = await apiClient.post(
        path,
        jsonData: jsonData,
        files: files,
        cancelToken: status?.cancelToken,
        onSendProgress: status?.progressCallback,
      );
      return resp;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        AppLogger().info("send`${apiClient.baseUrl}$path`: 请求取消.");
      } else {
        AppLogger().info("send`${apiClient.baseUrl}$path`: 请求失败.");
      }
    } catch (e) {
      throw Exception("send`${apiClient.baseUrl}$path`: 出错: $e");
    }
    return null;
  }
}
