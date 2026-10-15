import 'dart:math';

import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/models/label_tree.dart';

class EssayRereadPicker {
  final Random _random;
  final Set<String> _seen = {};
  String? _last;

  EssayRereadPicker({Random? random}) : _random = random ?? Random();

  Essay? pick(Iterable<Essay> essays, Iterable<Label> labels, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final pool = visibleEssays(essays, labels)
        .where(
          (essay) =>
              DateTime(essay.year, essay.month, essay.date.day).isBefore(day),
        )
        .toList();
    if (pool.isEmpty) return null;
    if (pool.every((essay) => _seen.contains(essay.id))) {
      _seen.clear();
      if (pool.length > 1 && _last != null) _seen.add(_last!);
    }
    final available = pool.where((essay) => !_seen.contains(essay.id)).toList();
    final anniversary = available
        .where(
          (essay) => essay.month == today.month && essay.date.day == today.day,
        )
        .toList();
    final candidates = anniversary.isNotEmpty ? anniversary : available;
    final essay = candidates[_random.nextInt(candidates.length)];
    _seen.add(essay.id);
    _last = essay.id;
    return essay;
  }
}
