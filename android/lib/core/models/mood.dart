import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

enum MoodType {
  happy('🥳', Colors.amber, '开心', '心情愉快'),
  calm('😌', Colors.teal, '平静', '心情平和'),
  sad('😢', Colors.blueGrey, '难过', '有点低落'),
  angry('😤', Colors.redAccent, '生气', '有点烦躁'),
  tired('😴', Colors.indigo, '疲惫', '感到疲惫');

  const MoodType(this.emoji, this.color, this.label, this.description);

  final String emoji;
  final Color color;
  final String label;
  final String description;
}

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
