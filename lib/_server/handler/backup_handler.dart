import 'dart:convert';
import 'dart:io';

import 'package:northstar/services/io/io_service.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

// 备份
class BackupHandler {
  // 备份booklet数据
  static Future<Response> backupBooklet(Request req) async {
    try {
      if (req.multipart() case final multipart?) {
        // 解析multipart请求.
        final jsonData = await _parseMultipart(
          multipart,
          await IoService.getSaveDir("static/img_storage/booklet"),
        );
        // 写入json数据.
        File(
          path.join(IoService.appDir, "static/booklet/styles.json"),
        ).writeAsString(jsonEncode(jsonData['styles']));
        File(
          path.join(IoService.appDir, "static/booklet/records.json"),
        ).writeAsString(jsonEncode(jsonData['records']));

        // 正常响应
        return Response.ok(
          jsonEncode({'status': 'backupEssay完成.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      // 默认对于post请求只接受formdata格式的.
      else {
        return Response.badRequest(
          body: jsonEncode({'status': '只能处理multipart请求.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(body: "backupBooklet内部错误: $e");
    }
  }

  // 备份essay数据
  static Future<Response> backupEssay(Request req) async {
    try {
      if (req.multipart() case final multipart?) {
        final jsonData = await _parseMultipart(
          multipart,
          await IoService.getSaveDir("static/img_storage/essay"),
        );
        File(
          path.join(IoService.appDir, "static/essay/year_summaries.json"),
        ).writeAsString(jsonEncode(jsonData['year_summaries']));
        File(
          path.join(IoService.appDir, "static/essay/labels.json"),
        ).writeAsString(jsonEncode(jsonData['labels']));
        File(
          path.join(IoService.appDir, "static/essay/essays.json"),
        ).writeAsString(jsonEncode(jsonData['essays']));

        return Response.ok(
          jsonEncode({'status': 'backupEssay完成.'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.badRequest(
          body: jsonEncode({'status': '只能处理multipart请求.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(body: "backupEssay内部错误: $e");
    }
  }

  // 解析multipart请求.
  static Future<Map<String, dynamic>> _parseMultipart(
    MultipartRequest multipart,
    Directory savedDir,
  ) async {
    Map<String, dynamic> jsonData = {};
    await for (final part in multipart.parts) {
      try {
        final partInfo = _parseContentDisposition(
          part.headers['content-disposition']!,
        );
        if (partInfo['name'] == "files") {
          final filename = partInfo['filename'];
          if (filename == null || filename.isEmpty) {
            throw Exception("_parseMultipart错误: 存在filename解析失败.");
          }

          final file = File(path.join(savedDir.path, filename));
          // await file.writeAsBytes(await part.readBytes());
          await part.pipe(file.openWrite());
        } else if (partInfo['name'] == "jsonData") {
          jsonData = jsonDecode(await part.readString());
        }
      } catch (e) {
        throw Exception("_parseMultipart出错: $e");
      }
    }
    return jsonData;
  }

  // 我去了part.headers格式竟然是:
  // {
  //   content-disposition: form-data; name="files"; filename="单词.png",
  //   content-type: image/png
  // }
  // 提取part.headers中的name和filename值.
  static Map<String, String> _parseContentDisposition(String disposition) {
    final result = <String, String>{};

    // 去掉开头的 "form-data"
    final parts = disposition.split(';');
    for (var part in parts) {
      part = part.trim();
      if (part.startsWith('name=')) {
        result['name'] = _extractValue(part);
      } else if (part.startsWith('filename=')) {
        result['filename'] = _extractValue(part);
      }
    }

    return result;
  }

  static String _extractValue(String part) {
    // 去掉 key=
    final value = part.split('=')[1].trim();
    // 如果有引号，去掉引号
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
  
}
