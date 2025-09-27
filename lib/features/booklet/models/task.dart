import 'package:hive/hive.dart';
import 'package:torrid/shared/utils/util.dart';

part 'task.g.dart';

@HiveType(typeId: 11)
class Task {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String image;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
  });

  Task.noId({
    required this.title,
    required this.description,
    required this.image,
  }): id=Util.generateId();

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: Util.generateId(),
      title: json['title'],
      description: json['description'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson(){
    return{
      "id": id,
      "title": title,
      "description": description,
      "image": image,
    };
  }
}
