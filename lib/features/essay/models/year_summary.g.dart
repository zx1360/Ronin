// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'year_summary.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class YearSummaryAdapter extends TypeAdapter<YearSummary> {
  @override
  final int typeId = 0;

  @override
  YearSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return YearSummary(
      year: fields[0] as String,
      essayCount: fields[1] as int,
      wordCount: fields[2] as int,
      monthSummaries: (fields[3] as List?)?.cast<MonthSummary>(),
    );
  }

  @override
  void write(BinaryWriter writer, YearSummary obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.essayCount)
      ..writeByte(2)
      ..write(obj.wordCount)
      ..writeByte(3)
      ..write(obj.monthSummaries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YearSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MonthSummaryAdapter extends TypeAdapter<MonthSummary> {
  @override
  final int typeId = 3;

  @override
  MonthSummary read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthSummary(
      month: fields[0] as String,
      essayCount: fields[1] as int,
      wordCount: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, MonthSummary obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.month)
      ..writeByte(1)
      ..write(obj.essayCount)
      ..writeByte(2)
      ..write(obj.wordCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthSummaryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
