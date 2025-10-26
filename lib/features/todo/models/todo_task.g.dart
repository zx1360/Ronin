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
      isMarked: fields[4] as bool,
      dueDate: fields[5] as DateTime?,
      reminder: fields[6] as DateTime?,
      priority: fields[7] as Priority,
      repeatCycle: fields[8] as RepeatCycle?,
      createAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TodoTask obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.desc)
      ..writeByte(3)
      ..write(obj.isDone)
      ..writeByte(4)
      ..write(obj.isMarked)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.reminder)
      ..writeByte(7)
      ..write(obj.priority)
      ..writeByte(8)
      ..write(obj.repeatCycle)
      ..writeByte(9)
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

class RepeatCycleAdapter extends TypeAdapter<RepeatCycle> {
  @override
  final int typeId = 17;

  @override
  RepeatCycle read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatCycle.once;
      case 1:
        return RepeatCycle.everyday;
      case 2:
        return RepeatCycle.workday;
      case 3:
        return RepeatCycle.weekend;
      case 4:
        return RepeatCycle.everyWeek;
      default:
        return RepeatCycle.once;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatCycle obj) {
    switch (obj) {
      case RepeatCycle.once:
        writer.writeByte(0);
        break;
      case RepeatCycle.everyday:
        writer.writeByte(1);
        break;
      case RepeatCycle.workday:
        writer.writeByte(2);
        break;
      case RepeatCycle.weekend:
        writer.writeByte(3);
        break;
      case RepeatCycle.everyWeek:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatCycleAdapter &&
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
      isMarked: json['isMarked'] as bool,
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
      'isMarked': instance.isMarked,
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
  RepeatCycle.everyWeek: 'everyWeek',
};
