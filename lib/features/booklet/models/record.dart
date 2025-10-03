import 'package:hive/hive.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/models/task.dart';
import 'package:torrid/features/booklet/services/booklet_hive_service.dart';
import 'package:torrid/shared/utils/util.dart';

part 'record.g.dart';

DateTime getTodayDate(){
  final today = DateTime.now();
  return DateTime(today.year, today.month, today.day);
}

@HiveType(typeId: 12)
class Record {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String styleId;

  @HiveField(2)
  late final DateTime date;

  @HiveField(3)
  String message;

  @HiveField(4)
  late final Map<String, bool> taskCompletion;

  Record({
    required this.id,
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
  });

  // TODO: 删掉.
  Record.noId({
    required this.styleId,
    required this.date,
    required this.message,
    required this.taskCompletion,
  }): id=Util.generateId();

  Record.empty({
    required this.styleId,
    this.message = "",
  }):id = Util.generateId(), date = getTodayDate(){
    taskCompletion = {};
    Style style = BookletHiveService.getAllStyles().where((item)=>item.id==styleId).first;
    for(Task task in style.tasks){
      taskCompletion.addAll({task.id: false});
    }
  }

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      // TODO: 只是临时这么些,  如果id还是之前的递增计数, 那就创建17位的id, 否则不动.
      id: (json['id']as String).length<17? Util.generateId(): json['id'],
      styleId: json['styleId'],
      date: DateTime.parse(json['date']),
      message: json['message'],
      taskCompletion: json['taskCompletion'],
    );
  }

  Map<String, dynamic> toJson(){
    return{
      "id": id,
      "styleId": styleId,
      "date": date.toLocal().toString().split(".").first,
      "message": message,
      "taskCompletion": taskCompletion,
    };
  }
}
