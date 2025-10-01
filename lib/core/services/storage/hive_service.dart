import 'dart:convert';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/features/essay/services/essay_hive_service.dart';
import 'package:torrid/core/services/network/http_service.dart';
import 'package:torrid/features/others/tuntun/services/tuntun_hive_service.dart';

class HiveService {
  static Future<void> init() async {
    final appDocumentDirectory = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDirectory.path);

    // 获取应用外部私有存储目录（Android的getExternalFilesDir，iOS的Documents）
    final directory = await getExternalStorageDirectory();
    if (directory == null) return;
    final bookletImgDir = path.join(directory.path, "img_storage/booklet");
    final essayImgDir = path.join(directory.path, "img_storage/essay");

    // 确保目录存在
    await Directory(bookletImgDir).create(recursive: true);
    await Directory(essayImgDir).create(recursive: true);
  }


  // # 同步所有数据, 从pc请求数据覆盖本地.
  static Future<void> syncDatas() async {
    await syncBooklet();
    await syncEssay();
    await syncTuntun();
  }

  // 同步booklet打卡
  static Future<void> syncBooklet() async {
    try {
      final pcIp = await HttpService.getPcIp();
      final response = await get(Uri.parse("http://$pcIp:4215/sync/booklet"));
      await BookletHiveService.syncData(jsonDecode(response.body));
    } catch (err) {
      // print(response);
      throw Exception("同步booklet数据出错.\n $err");
    }
  }

  // 同步essay随笔
  static Future<void> syncEssay() async {
    try {
      final pcIp = await HttpService.getPcIp();
      final response = await get(Uri.parse("http://$pcIp:4215/sync/essay"));
      await EssayHiveService.syncData(jsonDecode(response.body));
    } catch (err) {
      throw Exception("同步essay数据出错.$err\n");
    }
  }

  // 请求媒体文件info, status.
  static Future<void> syncTuntun() async {
    try{
      final pcIp = await HttpService.getPcIp();
      final resp = await get(Uri.parse("http://$pcIp:4215/tuntun/infos"));
      if(resp.statusCode==200){
        TuntunHiveService.initTuntun(jsonDecode(resp.body));
      }else{
        throw Exception("请求出错.");
      }
    }catch(err){
      throw Exception("syncTuntun:$err");
    }
  }



  // # 更新所有数据, 本地数据上传到PC.
  static Future<void> updateDatas() async {
    await updateBooklet();
    await updateEssay();
    await updateTuntun();
  }

  // 同步booklet打卡
  static Future<void> updateBooklet() async {
    try {
      final packedData = BookletHiveService.packUp();
      final pcIp = await HttpService.getPcIp();
      await post(
        Uri.parse("http://$pcIp:4215/update/booklet"),
        headers: {"Content-Type": "application/json"},
        body: packedData,
      );
      List<String> urls = BookletHiveService.getImgsPath();
      HttpService.uploadImages(
        urls,
        "http://$pcIp:4215/update/booklet_imgs",
      ).catchError((error) {
        print("上传出错.");
      });
    } catch (err) {
      throw Exception("同步booklet数据出错.\n$err");
    }
  }

  // 更新essay随笔
  static Future<void> updateEssay() async {
    try {
      final packedData = EssayHiveService.packUp();
      final pcIp = await HttpService.getPcIp();
      await post(
        Uri.parse("http://$pcIp:4215/update/essay"),
        headers: {"Content-Type": "application/json"},
        body: packedData,
      );
      List<String> urls = EssayHiveService.getImgsPath();
      HttpService.uploadImages(
        urls,
        "http://$pcIp:4215/update/essay_imgs",
      ).catchError((error) {
        print("上传出错.");
      });
    } catch (err) {
      throw Exception("同步booklet数据出错.\n$err");
    }
  }

  // 将Tuntun的操作记录status.json上传到服务器.
  static Future<void> updateTuntun() async {}
}
