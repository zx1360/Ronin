import 'package:hive_flutter/hive_flutter.dart';

part 'info.g.dart';

@HiveType(typeId: 20)
class Info {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String filePath;

  @HiveField(2)
  final String ext;

  @HiveField(3)
  final int fileSize;

  @HiveField(4)
  final int createTime;

  @HiveField(5)
  final int modifyTime;

  @HiveField(6)
  final String mimeType;

  Info({
    required this.id,
    required this.filePath,
    required this.ext,
    required this.fileSize,
    required this.createTime,
    required this.modifyTime,
    required this.mimeType,
  });

  factory Info.fromJson(Map<String, dynamic> json) {
    return Info(
      id: json['id'],
      filePath: json['file_path'],
      ext: json['ext'],
      fileSize: json['file_size'],
      createTime: json['create_time'],
      modifyTime: json['modify_time'],
      mimeType: json['mime_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_path': filePath,
      'ext': ext,
      'file_size': fileSize,
      'create_time': createTime,
      'modify_time': modifyTime,
      'mime_type': mimeType,
    };
  }

  Info copyWith({
    String? id,
    String? filePath,
    String? ext,
    int? fileSize,
    int? createTime,
    int? modifyTime,
    String? mimeType,
  }) {
    return Info(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      ext: ext ?? this.ext,
      fileSize: fileSize ?? this.fileSize,
      createTime: createTime ?? this.createTime,
      modifyTime: modifyTime ?? this.modifyTime,
      mimeType: mimeType ?? this.mimeType,
    );
  }
}