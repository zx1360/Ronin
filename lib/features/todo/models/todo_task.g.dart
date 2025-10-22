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
      repeatCycle: fields[7] as RepeatCycle?,
      createAt: fields[8] as DateTime?,
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
      ..write(obj.repeatCycle)
      ..writeByte(8)
      ..write(obj.createAt);
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
      repeatCycle:
          $enumDecodeNullable(_$RepeatCycleEnumMap, json['repeatCycle']),
      createAt: json['createAt'] == null
          ? null
          : DateTime.parse(json['createAt'] as String),
    );

Map<String, dynamic> _$TodoTaskToJson(TodoTask instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'desc': instance.desc,
      'isDone': instance.isDone,
      'dueDate': instance.dueDate?.toIso8601String(),
      'reminder': instance.reminder?.toIso8601String(),
      'priority': _$PriorityEnumMap[instance.priority]!,
      'repeatCycle': _$RepeatCycleEnumMap[instance.repeatCycle],
      'createAt': instance.createAt.toIso8601String(),
    };

const _$PriorityEnumMap = {
  Priority.low: 'low',
  Priority.medium: 'medium',
  Priority.high: 'high',
  Priority.intensive: 'intensive',
};

const _$RepeatCycleEnumMap = {
  RepeatCycle.once: 'once',
  RepeatCycle.everyday: 'everyday',
  RepeatCycle.workday: 'workday',
  RepeatCycle.weekend: 'weekend',
  RepeatCycle.everyWeek: 'everyday',
};
