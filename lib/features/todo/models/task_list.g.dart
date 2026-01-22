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
      order: fields[2] as int,
      isDefault: fields[3] as bool,
      themeColor: fields[4] as ListThemeColor,
      iconCodePoint: fields[5] as int?,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskList obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.order)
      ..writeByte(3)
      ..write(obj.isDefault)
      ..writeByte(4)
      ..write(obj.themeColor)
      ..writeByte(5)
      ..write(obj.iconCodePoint)
      ..writeByte(6)
      ..write(obj.createdAt);
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

class ListThemeColorAdapter extends TypeAdapter<ListThemeColor> {
  @override
  final int typeId = 25;

  @override
  ListThemeColor read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ListThemeColor.blue;
      case 1:
        return ListThemeColor.red;
      case 2:
        return ListThemeColor.orange;
      case 3:
        return ListThemeColor.green;
      case 4:
        return ListThemeColor.purple;
      case 5:
        return ListThemeColor.pink;
      case 6:
        return ListThemeColor.teal;
      case 7:
        return ListThemeColor.brown;
      default:
        return ListThemeColor.blue;
    }
  }

  @override
  void write(BinaryWriter writer, ListThemeColor obj) {
    switch (obj) {
      case ListThemeColor.blue:
        writer.writeByte(0);
        break;
      case ListThemeColor.red:
        writer.writeByte(1);
        break;
      case ListThemeColor.orange:
        writer.writeByte(2);
        break;
      case ListThemeColor.green:
        writer.writeByte(3);
        break;
      case ListThemeColor.purple:
        writer.writeByte(4);
        break;
      case ListThemeColor.pink:
        writer.writeByte(5);
        break;
      case ListThemeColor.teal:
        writer.writeByte(6);
        break;
      case ListThemeColor.brown:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListThemeColorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
