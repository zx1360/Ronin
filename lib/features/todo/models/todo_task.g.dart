// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoStepAdapter extends TypeAdapter<TodoStep> {
  @override
  final int typeId = 24;

  @override
  TodoStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TodoStep(
      id: fields[0] as String,
      title: fields[1] as String,
      isDone: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TodoStep obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isDone);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

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
      note: fields[2] as String?,
      isDone: fields[3] as bool,
      dueDate: fields[4] as DateTime?,
      reminder: fields[5] as DateTime?,
      priority: fields[6] as Priority,
      createdAt: fields[7] as DateTime?,
      completedAt: fields[8] as DateTime?,
      isMyDay: fields[9] as bool,
      myDayDate: fields[10] as DateTime?,
      repeatType: fields[11] as RepeatType,
      steps: (fields[12] as List).cast<TodoStep>(),
      listId: fields[13] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TodoTask obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.note)
      ..writeByte(3)
      ..write(obj.isDone)
      ..writeByte(4)
      ..write(obj.dueDate)
      ..writeByte(5)
      ..write(obj.reminder)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.completedAt)
      ..writeByte(9)
      ..write(obj.isMyDay)
      ..writeByte(10)
      ..write(obj.myDayDate)
      ..writeByte(11)
      ..write(obj.repeatType)
      ..writeByte(12)
      ..write(obj.steps)
      ..writeByte(13)
      ..write(obj.listId);
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
        return Priority.normal;
      case 1:
        return Priority.important;
      default:
        return Priority.normal;
    }
  }

  @override
  void write(BinaryWriter writer, Priority obj) {
    switch (obj) {
      case Priority.normal:
        writer.writeByte(0);
        break;
      case Priority.important:
        writer.writeByte(1);
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

class RepeatTypeAdapter extends TypeAdapter<RepeatType> {
  @override
  final int typeId = 23;

  @override
  RepeatType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RepeatType.none;
      case 1:
        return RepeatType.daily;
      case 2:
        return RepeatType.weekdays;
      case 3:
        return RepeatType.weekly;
      case 4:
        return RepeatType.monthly;
      case 5:
        return RepeatType.yearly;
      default:
        return RepeatType.none;
    }
  }

  @override
  void write(BinaryWriter writer, RepeatType obj) {
    switch (obj) {
      case RepeatType.none:
        writer.writeByte(0);
        break;
      case RepeatType.daily:
        writer.writeByte(1);
        break;
      case RepeatType.weekdays:
        writer.writeByte(2);
        break;
      case RepeatType.weekly:
        writer.writeByte(3);
        break;
      case RepeatType.monthly:
        writer.writeByte(4);
        break;
      case RepeatType.yearly:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepeatTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TodoStep _$TodoStepFromJson(Map<String, dynamic> json) => TodoStep(
      id: json['id'] as String,
      title: json['title'] as String,
      isDone: json['isDone'] as bool? ?? false,
    );

Map<String, dynamic> _$TodoStepToJson(TodoStep instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'isDone': instance.isDone,
    };

TodoTask _$TodoTaskFromJson(Map<String, dynamic> json) => TodoTask(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      isDone: json['isDone'] as bool? ?? false,
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
      reminder: json['reminder'] == null
          ? null
          : DateTime.parse(json['reminder'] as String),
      priority: $enumDecodeNullable(_$PriorityEnumMap, json['priority']) ??
          Priority.normal,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      isMyDay: json['isMyDay'] as bool? ?? false,
      myDayDate: json['myDayDate'] == null
          ? null
          : DateTime.parse(json['myDayDate'] as String),
      repeatType:
          $enumDecodeNullable(_$RepeatTypeEnumMap, json['repeatType']) ??
              RepeatType.none,
      steps: (json['steps'] as List<dynamic>?)
              ?.map((e) => TodoStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      listId: json['listId'] as String,
    );

Map<String, dynamic> _$TodoTaskToJson(TodoTask instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'note': instance.note,
      'isDone': instance.isDone,
      'dueDate': instance.dueDate?.toIso8601String(),
      'reminder': instance.reminder?.toIso8601String(),
      'priority': _$PriorityEnumMap[instance.priority]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'isMyDay': instance.isMyDay,
      'myDayDate': instance.myDayDate?.toIso8601String(),
      'repeatType': _$RepeatTypeEnumMap[instance.repeatType]!,
      'steps': instance.steps,
      'listId': instance.listId,
    };

const _$PriorityEnumMap = {
  Priority.normal: 'normal',
  Priority.important: 'important',
};

const _$RepeatTypeEnumMap = {
  RepeatType.none: 'none',
  RepeatType.daily: 'daily',
  RepeatType.weekdays: 'weekdays',
  RepeatType.weekly: 'weekly',
  RepeatType.monthly: 'monthly',
  RepeatType.yearly: 'yearly',
};
