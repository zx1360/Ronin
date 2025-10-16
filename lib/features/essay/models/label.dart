import 'package:hive/hive.dart';
import 'package:torrid/shared/utils/util.dart';

part 'label.g.dart';

@HiveType(typeId: 2)
class Label {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int essayCount;

  Label({required this.id, required this.name, required this.essayCount});

  factory Label.fromJson(Map<String, dynamic> json) {
    // TODO: 等待格式统一.
    print((json['id']as String).length<17);
    print(json['id']);
    return Label(
      id: (json['id']as String).length<17? generateId(): json['id'],
      name: json['name'],
      essayCount: json['essayCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "name": name, "essayCount": essayCount};
  }
}
