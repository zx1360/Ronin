import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/network/api_client.dart';

/// 网络文件传输服务
///
/// 负责从远程服务器下载文件并保存到本地存储。
/// 将网络传输逻辑与状态管理解耦，便于测试和复用。
class TransferService {
  final ApiClient _apiClient;

  TransferService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// 从相对URL批量下载文件并保存到指定目录
  ///
  /// [urls] - 相对路径列表，会自动添加 `/static/` 前缀
  /// [relativeDir] - 保存目标的相对目录路径（相对于应用外部私有空间）
  /// [clearBeforeSave] - 保存前是否清空目标目录，默认为 true
  /// [concurrentLimit] - 并发下载数量限制，默认为 5
  ///
  /// 抛出 [Exception] 当下载或保存失败时
  Future<void> downloadAndSaveFiles({
    required List<String> urls,
    required String relativeDir,
    bool clearBeforeSave = true,
    int concurrentLimit = 5,
  }) async {
    if (urls.isEmpty) return;

    try {
      // 清空目标目录（可选）
      if (clearBeforeSave) {
        await IoService.clearSpecificDirectory(relativeDir);
      }

      // 确保目标目录存在
      final targetDir = await IoService.ensureDirExists(relativeDir);

      // 使用并发限制的批量下载
      await _downloadFilesWithConcurrencyLimit(
        urls: urls,
        targetDir: targetDir,
        concurrentLimit: concurrentLimit,
      );
    } catch (e) {
      throw Exception("批量下载保存文件失败\n$e");
    }
  }

  /// 带并发限制的批量文件下载
  Future<void> _downloadFilesWithConcurrencyLimit({
    required List<String> urls,
    required Directory targetDir,
    required int concurrentLimit,
  }) async {
    // 将 URL 列表分批处理，每批最多 concurrentLimit 个
    for (var i = 0; i < urls.length; i += concurrentLimit) {
      final batch = urls.skip(i).take(concurrentLimit).toList();

      // 并行下载当前批次
      await Future.wait(
        batch.map(
          (url) => _downloadAndSaveFile(url: url, targetDir: targetDir),
        ),
      );
    }
  }

  /// 下载单个文件并保存
  Future<void> _downloadAndSaveFile({
    required String url,
    required Directory targetDir,
  }) async {
    final requestPath = "/static/$url";

    try {
      final response = await _apiClient.getBinary(requestPath);

      if (response.statusCode != 200) {
        throw Exception('文件请求失败: $url, 状态码: ${response.statusCode}');
      }

      final Uint8List? fileData = response.data;
      if (fileData == null || fileData.isEmpty) {
        throw Exception('文件数据为空: $url');
      }

      // 保存文件
      final String fileName = path.basename(url);
      final String savePath = path.join(targetDir.path, fileName);
      final File file = File(savePath);
      await file.writeAsBytes(fileData);

      AppLogger().debug("文件下载保存成功: $fileName");
    } catch (e) {
      AppLogger().error("下载文件失败: $url, 错误: $e");
      rethrow;
    }
  }

  /// 下载单个文件并返回字节数据（不保存到磁盘）
  ///
  /// [relativePath] - 相对路径，会自动添加 `/static/` 前缀
  ///
  /// 返回文件的字节数据，失败时返回 null
  Future<Uint8List?> downloadFile(String relativePath) async {
    try {
      final response = await _apiClient.getBinary("/static/$relativePath");

      if (response.statusCode != 200) {
        AppLogger().error('文件请求失败: $relativePath, 状态码: ${response.statusCode}');
        return null;
      }

      return response.data;
    } catch (e) {
      AppLogger().error("下载文件失败: $relativePath, 错误: $e");
      return null;
    }
  }
}
