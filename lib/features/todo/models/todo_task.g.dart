// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoTaskAdapter extends TypeAdapter<TodoTask> {
  @override
  final int typeId = 19;

  @override
  TodoTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TodoTask(
      id: fields[0] as String,
      title: fields[1] as String,
      desc: fields[2] as String?,
      isDone: fields[3] as bool,
      dueDate: fields[4] as DateTime?,
      reminder: fields[5] as DateTime?,
      priority: fields[6] as Priority,
      createAt: fields[7] as DateTime?,
      doneAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TodoTask obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.desc)
      ..writeByte(3)
      ..write(obj.isDone)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.reminder)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.createAt)
      ..writeByte(8)
      ..write(obj.doneAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PriorityAdapter extends TypeAdapter<Priority> {
  @override
  final int typeId = 16;

  @override
  Priority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Priority.low;
      case 1:
        return Priority.medium;
      case 2:
        return Priority.high;
      case 3:
        return Priority.intensive;
      default:
        return Priority.low;
    }
  }

  @override
  void write(BinaryWriter writer, Priority obj) {
    switch (obj) {
      case Priority.low:
        writer.writeByte(0);
        break;
      case Priority.medium:
        writer.writeByte(1);
        break;
      case Priority.high:
        writer.writeByte(2);
        break;
      case Priority.intensive:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodoTask _$TodoTaskFromJson(Map<String, dynamic> json) => TodoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      desc: json['desc'] as String?,
      isDone: json['isDone'] as bool,
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      reminder: json['reminder'] == null
          ? null
          : DateTime.parse(json['reminder'] as String),
      priority: $enumDecode(_$PriorityEnumMap, json['priority']),
      createAt: json['createAt'] == null
          ? null
          : DateTime.parse(json['createAt'] as String),
      doneAt: json['doneAt'] == null
          ? null
          : DateTime.parse(json['doneAt'] as String),
    );

Map<String, dynamic> _$TodoTaskToJson(TodoTask instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'desc': instance.desc,
      'isDone': instance.isDone,
      'dueDate': instance.dueDate?.toIso8601String(),
      'reminder': instance.reminder?.toIso8601String(),
      'priority': _$PriorityEnumMap[instance.priority]!,
      'createAt': instance.createAt.toIso8601String(),
      'doneAt': instance.doneAt?.toIso8601String(),
    };

const _$PriorityEnumMap = {
  Priority.low: 'low',
  Priority.medium: 'medium',
  Priority.high: 'high',
  Priority.intensive: 'intensive',
};
