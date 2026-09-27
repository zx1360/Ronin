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
      createdAt: fields[4] as DateTime?,
      updatedAt: fields[5] as DateTime?,
      deletedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, YearSummary obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.essayCount)
      ..writeByte(2)
      ..write(obj.wordCount)
      ..writeByte(3)
      ..write(obj.monthSummaries)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.deletedAt);
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

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

YearSummary _$YearSummaryFromJson(Map<String, dynamic> json) => YearSummary(
      year: json['year'] as String,
      essayCount: (json['essay_count'] as num?)?.toInt() ?? 0,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
      monthSummaries: (json['month_summaries'] as List<dynamic>?)
          ?.map((e) => MonthSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: syncTimeFromJson(json['created_at'] as String?),
      updatedAt: syncTimeFromJson(json['updated_at'] as String?),
      deletedAt: syncTimeFromJson(json['deleted_at'] as String?),
    );

Map<String, dynamic> _$YearSummaryToJson(YearSummary instance) =>
    <String, dynamic>{
      'year': instance.year,
      'essay_count': instance.essayCount,
      'word_count': instance.wordCount,
      'month_summaries': instance.monthSummaries,
      'created_at': syncTimeToJson(instance.createdAt),
      'updated_at': syncTimeToJson(instance.updatedAt),
      'deleted_at': syncTimeToJson(instance.deletedAt),
    };

MonthSummary _$MonthSummaryFromJson(Map<String, dynamic> json) => MonthSummary(
      month: json['month'] as String,
      essayCount: (json['essay_count'] as num?)?.toInt() ?? 0,
      wordCount: (json['word_count'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$MonthSummaryToJson(MonthSummary instance) =>
    <String, dynamic>{
      'month': instance.month,
      'essay_count': instance.essayCount,
      'word_count': instance.wordCount,
    };
