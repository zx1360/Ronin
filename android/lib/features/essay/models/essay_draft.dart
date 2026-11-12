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
}
