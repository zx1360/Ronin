import 'package:torrid/features/essay/models/essay.dart';

class EssayDraft {
  final Essay essay;
  final Essay? original;
  final DateTime updatedAt;

  const EssayDraft({
    required this.essay,
    this.original,
    required this.updatedAt,
  });

  bool get hasContent =>
      essay.title.trim().isNotEmpty ||
      essay.content.trim().isNotEmpty ||
      essay.imgs.isNotEmpty ||
      essay.labels.isNotEmpty ||
      essay.mood != null;

  factory EssayDraft.fromJson(Map<String, dynamic> json) => EssayDraft(
    essay: Essay.fromJson(json['essay'] as Map<String, dynamic>),
    original: json['original'] == null
        ? null
        : Essay.fromJson(json['original'] as Map<String, dynamic>),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'essay': essay.toJson(),
    'original': original?.toJson(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
