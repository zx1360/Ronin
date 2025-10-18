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

  Label copyWith({String? id, String? name, int? essayCount}) {
    return Label(
      id: id ?? this.id,
      name: name ?? this.name,
      essayCount: essayCount ?? this.essayCount,
    );
  }

  factory Label.newOne(String name) {
    return Label(id: generateId(), name: name, essayCount: 0);
  }

  factory Label.fromJson(Map<String, dynamic> json) {
    // TODO: 等待格式统一.
    print((json['id'] as String).length < 17);
    print(json['id']);
    return Label(
      id: (json['id'] as String).length < 17 ? generateId() : json['id'],
      name: json['name'],
      essayCount: json['essayCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "name": name, "essayCount": essayCount};
  }
}
