// GET请求图片并保存到安卓应用的外部私有空间
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:torrid/services/io/io_service.dart';
import 'package:torrid/services/storage/prefs_service.dart';

// TODO: 之后改成使用这个, 请求多个图片保存到本地.
Future<void> saveFromRelativeUrls(List<String> urls, String relativeDir) async {
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

    // TODO: 在ApiHandler改为单例模式之后, 用它发送请求, 省去获重复取ip,port.
    final prefs = PrefsService().prefs;
    final pcIp = prefs.getString("PC_IP");
    final pcPort = prefs.getString("PC_PORT");
    // 请求图片
    for (final url in urls) {
      final response = await get(Uri.parse("http://$pcIp:$pcPort/static/$url"));
      if (response.statusCode != 200) {
        throw Exception('图片请求失败，状态码: ${response.statusCode}');
      }

      // 获取图片数据
      final Uint8List imageData = response.bodyBytes;
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
