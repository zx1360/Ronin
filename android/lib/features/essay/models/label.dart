import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:torrid/core/utils/util.dart';

part 'label.g.dart';

@HiveType(typeId: 2)
@JsonSerializable(fieldRename: FieldRename.snake)
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

  // (反)序列化
  factory Label.fromJson(Map<String, dynamic> json)=> _$LabelFromJson(json);
  Map<String, dynamic> toJson() => _$LabelToJson(this);
}
