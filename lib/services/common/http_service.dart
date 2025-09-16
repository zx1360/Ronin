import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HttpService {
  /// 将本地图片上传到指定url
  /// [relativePaths] 本地图片url列表
  /// [url] 目标网络地址
  static Future<void> uploadImages(List<String> relativePaths, String url) async {
    // 用于跟踪上次显示的进度百分比
    int lastReportedProgress = -1;
    try {
      // 获取外部存储目录
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法获取外部存储目录");
      }

      // 创建Dio实例
      final dio = Dio();
      
      // 准备FormData
      final formData = FormData();
      
      // 添加所有图片文件
      for (var i = 0; i < relativePaths.length; i++) {
        // 构建完整文件路径
        final filePath = "${externalDir.path}/${relativePaths[i]}";
        final file = File(filePath);
        
        // 检查文件是否存在
        if (!await file.exists()) {
          print("文件不存在: $filePath");
          continue;
        }
        
        // 添加到FormData，使用multipart/form-data格式
        formData.files.add(MapEntry(
          "images[]", // 服务器端将通过此key获取文件数组
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last, // 获取文件名
          ),
        ));
      }
      
      // 发送POST请求
      final response = await dio.post(
        url,
        data: formData,
        options: Options(
          contentType: Headers.multipartFormDataContentType,
        ),
        onSendProgress: (int sent, int total) {
          if (total > 0) {
            // 计算当前进度百分比（取整数）
            final progress = (sent / total * 100).toInt();
            
            // 只在进度是10%的倍数且与上次显示的不同时才打印
            if (progress % 10 == 0 && progress != lastReportedProgress) {
              print("上传进度: $progress%");
              lastReportedProgress = progress;
            }
          }
        },
      );
      
      // 处理响应
      if (response.statusCode == 200) {
        print("上传成功: ${response.data}");
      } else {
        print("上传失败: 状态码 ${response.statusCode}");
      }
    } catch (e) {
      print("上传出错: $e");
      rethrow;
    }
  }

  // 获取pc端的ip
  static Future getPcIp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("PC_IP");
  }
  
}