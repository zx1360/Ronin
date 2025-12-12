// TODO: 闲下来这部分改用riverpod管理. 分离到其他地方.
// GET请求图片并保存到安卓应用的外部私有空间
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/core/services/io/io_service.dart';

part 'network_provider.g.dart';

@riverpod
Future<void> saveFromRelativeUrls(
  SaveFromRelativeUrlsRef ref, {
  required List<String> urls,
  required String relativeDir,
}) async {
  try {
    await IoService.clearSpecificDirectory(relativeDir);
    // 获取应用的外部私有存储目录
    // 对于Android，这是位于外部存储的Android/data/[包名]/files/目录
    final externalDir = await IoService.externalStorageDir;

    // 创建目标文件所在的目录, 确保目录存在
    final targetDir = path.join(externalDir.path, relativeDir);
    final directory = Directory(targetDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // TODO: 此处网络相关之后分离到transfer_service.dart中.
    // TODO: 本文件重构, 状态相关使用riverpod实现, 结合apiCliantManagerProvider.
    // 请求图片
    // TODO: 并非完全异步, 待优化.
    for (final url in urls) {
      final response = await ref.read(
        bytesFetcherProvider(path: "/static/$url").future,
      );
      if (response == null || response.statusCode != 200) {
        throw Exception('图片请求失败:\nurl: $url\n状态码: ${response?.statusCode}');
      }

      // 获取图片数据
      final Uint8List imageData = response.data!;
      final String fileName = path.basename(url);
      final String savePath = path.join(targetDir, fileName);

      // 将图片数据写入文件
      final File imageFile = File(savePath);
      await imageFile.writeAsBytes(imageData);
    }
  } catch (e) {
    throw Exception("保存到应用外部私有空间失败\n$e");
  }
}
