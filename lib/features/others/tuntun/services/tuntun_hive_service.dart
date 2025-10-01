import 'package:hive_flutter/adapters.dart';
import 'package:torrid/features/others/tuntun/models/info.dart';
import 'package:torrid/features/others/tuntun/models/status.dart';

class TuntunHiveService {
  static const String infoBoxName = "mediaInfo";
  static const String statusBoxName = "mediaStatus";

  static Future<void> init() async {
    Hive.registerAdapter(InfoAdapter());
    Hive.registerAdapter(StatusAdapter());

    await Hive.openBox<Info>(infoBoxName);
    await Hive.openBox<Status>(statusBoxName);
  }

  static Box<Info> get _infoBox => Hive.box(infoBoxName);
  static Box<Status> get _statusBox => Hive.box(statusBoxName);

  // 根据info.json和status.json初始化数据.
  static Future<void> initTuntun(dynamic json) async {
    try {
      final infos = json['infos'];
      final status = json['status'];
      await _infoBox.clear();
      await _statusBox.clear();
      for(dynamic info in infos){
        Info info_ = Info.fromJson(info);
        _infoBox.put(info_.id, info_);
      }
      for(dynamic status_ in status){
        Status status__ = Status.fromJson(status_);
        _statusBox.put(status__.mediaId, status__);
      }
    } catch (err) {
      throw Exception("initTuntun:$err");
    }
  }

  
}
