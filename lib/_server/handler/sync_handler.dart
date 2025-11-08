import 'dart:convert';
import 'dart:io';

import 'package:northstar/services/io/io_service.dart';
import 'package:path/path.dart'as path;
import 'package:shelf/shelf.dart';

// 同步
class SyncHandler {
  // 同步booklet数据
  static Future<Response> syncBooklet(Request req)async{
    final targetDir =  path.join(IoService.appDir, "static/booklet");
    final Map<String, dynamic> data = {};
    final styleFile = File(path.join(targetDir, "styles.json"));
    final recordFile = File(path.join(targetDir, "records.json"));
    data['styles'] = jsonDecode(await styleFile.readAsString());
    data['records'] = jsonDecode(await recordFile.readAsString());
    
    return Response.ok(
      jsonEncode(data),
      headers: {"Content-Type": "application/json"}
    );
  }


  // 同步essay数据.
  static Future<Response> syncEssay(Request req)async{
    final targetDir =  path.join(IoService.appDir, "static/essay");
    final Map<String, dynamic> data = {};
    final summaryFile = File(path.join(targetDir, "year_summaries.json"));
    final labelFile = File(path.join(targetDir, "labels.json"));
    final essayFile = File(path.join(targetDir, "essays.json"));
    data['year_summaries'] = jsonDecode(await summaryFile.readAsString());
    data['labels'] = jsonDecode(await labelFile.readAsString());
    data['essays'] = jsonDecode(await essayFile.readAsString());
    
    return Response.ok(
      jsonEncode(data),
      headers: {"Content-Type": "application/json"}
    );
  }
}