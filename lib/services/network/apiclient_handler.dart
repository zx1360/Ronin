import 'dart:io';

import 'package:torrid/services/debug/logging_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';

import 'package:torrid/services/network/api_client.dart';
import 'package:dio/dio.dart';

import 'package:torrid/shared/models/network_status.dart';


// TODO: Dio虽轻量, 但是调用fetch(), send()都会创建ApiClient和Dio实例, 试着改为单例呢?
class ApiclientHandler {
  // GET请求封装
  static Future<Response?> fetch({
    required String path,
    NetworkStatus? status,
    Map<String, dynamic> params = const {},
  }) async {
    final prefs = PrefsService().prefs;
    final pcIp = prefs.getString("PC_IP");
    final pcPort = prefs.getString("PC_PORT");
    final apiClient = ApiClient(baseUrl: "http://$pcIp:$pcPort");
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
    final prefs = PrefsService().prefs;
    final pcIp = prefs.getString("PC_IP");
    final pcPort = prefs.getString("PC_PORT");
    final apiClient = ApiClient(baseUrl: "http://$pcIp:$pcPort");
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
