// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_timer_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CountdownTimerModelAdapter extends TypeAdapter<CountdownTimerModel> {
  @override
  final int typeId = 101;

  @override
  CountdownTimerModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CountdownTimerModel(
      id: fields[0] as String,
      name: fields[1] as String,
      totalSeconds: fields[2] as int,
      remainingSeconds: fields[3] as int,
      status: fields[4] as CountdownTimerStatus,
      lastUpdateTime: fields[5] as DateTime?,
      startTime: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, CountdownTimerModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.totalSeconds)
      ..writeByte(3)
      ..write(obj.remainingSeconds)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.lastUpdateTime)
      ..writeByte(6)
      ..write(obj.startTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownTimerModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CountdownTimerStatusAdapter extends TypeAdapter<CountdownTimerStatus> {
  @override
  final int typeId = 100;

  @override
  CountdownTimerStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CountdownTimerStatus.idle;
      case 1:
        return CountdownTimerStatus.running;
      case 2:
        return CountdownTimerStatus.completed;
      default:
        return CountdownTimerStatus.idle;
    }
  }

  @override
  void write(BinaryWriter writer, CountdownTimerStatus obj) {
    switch (obj) {
      case CountdownTimerStatus.idle:
        writer.writeByte(0);
        break;
      case CountdownTimerStatus.running:
        writer.writeByte(1);
        break;
      case CountdownTimerStatus.completed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountdownTimerStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
