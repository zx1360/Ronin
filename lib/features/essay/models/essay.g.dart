// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EssayAdapter extends TypeAdapter<Essay> {
  @override
  final int typeId = 1;

  @override
  Essay read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Essay(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      wordCount: fields[2] as int,
      content: fields[3] as String,
      imgs: (fields[4] as List).cast<String>(),
      labels: (fields[5] as List).cast<String>(),
      messages: (fields[6] as List).cast<Message>(),
    );
  }

  @override
  void write(BinaryWriter writer, Essay obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.wordCount)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.imgs)
      ..writeByte(5)
      ..write(obj.labels)
      ..writeByte(6)
      ..write(obj.messages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EssayAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Essay _$EssayFromJson(Map<String, dynamic> json) => Essay(
      id: json['id'] as String,
      date: dateFromJson(json['date'] as String),
      wordCount: (json['word_count'] as num).toInt(),
      content: json['content'] as String,
      imgs: (json['imgs'] as List<dynamic>).map((e) => e as String).toList(),
      labels:
          (json['labels'] as List<dynamic>).map((e) => e as String).toList(),
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$EssayToJson(Essay instance) => <String, dynamic>{
      'id': instance.id,
      'date': dateToJson(instance.date),
      'word_count': instance.wordCount,
      'content': instance.content,
      'imgs': instance.imgs,
      'labels': instance.labels,
      'messages': instance.messages,
    };
