// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_list.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskListAdapter extends TypeAdapter<TaskList> {
  @override
  final int typeId = 18;

  @override
  TaskList read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskList(
      id: fields[0] as String,
      name: fields[1] as String,
      tasks: (fields[2] as List).cast<TodoTask>(),
      isDefault: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaskList obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.tasks)
      ..writeByte(3)
      ..write(obj.isDefault);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskListAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskList _$TaskListFromJson(Map<String, dynamic> json) => TaskList(
      id: json['id'] as String,
      name: json['name'] as String,
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => TodoTask.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$TaskListToJson(TaskList instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'tasks': instance.tasks,
      'isDefault': instance.isDefault,
    };
