import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mood.g.dart';

/// 心情类型枚举 - 使用表情符号表示心情
/// 便于扩展：只需添加新的枚举值和对应的图标/颜色即可
@HiveType(typeId: 8)
enum MoodType {
  @HiveField(0)
  happy,      // 开心 - 非常愉快

  @HiveField(1)
  calm,       // 平静 - 心情平和

  @HiveField(2)
  sad,        // 难过 - 有点低落

  @HiveField(3)
  angry,      // 生气 - 烦躁/愤怒

  @HiveField(4)
  tired,      // 疲惫 - 累/困倦
}

/// 心情扩展方法 - 提供图标、颜色、描述等
extension MoodTypeExtension on MoodType {
  /// 获取对应的 emoji 表情
  String get emoji {
    switch (this) {
      case MoodType.happy:
        return '🥳';  // 开心大笑
      case MoodType.calm:
        return '😌';  // 平静舒适
      case MoodType.sad:
        return '😢';  // 难过流泪
      case MoodType.angry:
        return '😤';  // 生气
      case MoodType.tired:
        return '😴';  // 困倦
    }
  }

  /// 获取对应的颜色
  Color get color {
    switch (this) {
      case MoodType.happy:
        return Colors.amber;
      case MoodType.calm:
        return Colors.teal;
      case MoodType.sad:
        return Colors.blueGrey;
      case MoodType.angry:
        return Colors.redAccent;
      case MoodType.tired:
        return Colors.indigo;
    }
  }

  /// 获取描述文字
  String get label {
    switch (this) {
      case MoodType.happy:
        return '开心';
      case MoodType.calm:
        return '平静';
      case MoodType.sad:
        return '难过';
      case MoodType.angry:
        return '生气';
      case MoodType.tired:
        return '疲惫';
    }
  }

  /// 获取心情描述
  String get description {
    switch (this) {
      case MoodType.happy:
        return '心情愉快';
      case MoodType.calm:
        return '心情平和';
      case MoodType.sad:
        return '有点低落';
      case MoodType.angry:
        return '有点烦躁';
      case MoodType.tired:
        return '感到疲惫';
    }
  }
}

/// MoodType 的 JSON 序列化辅助
class MoodTypeConverter implements JsonConverter<MoodType?, String?> {
  const MoodTypeConverter();

  @override
  MoodType? fromJson(String? json) {
    if (json == null) return null;
    return MoodType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => MoodType.calm,
    );
  }

  @override
  String? toJson(MoodType? object) => object?.name;
}
