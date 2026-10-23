import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';

class BookletHistoryEntry {
  final Record record;
  final Style? style;

  const BookletHistoryEntry(this.record, this.style);

  int get completedCount => style == null
      ? record.taskCompletion.values.where((done) => done).length
      : style!.tasks
            .where((task) => record.taskCompletion[task.id] == true)
            .length;

  int get taskCount => style?.tasks.length ?? record.taskCompletion.length;
}

List<BookletHistoryEntry> buildBookletHistory(
  List<Record> records,
  List<Style> styles, {
  String? styleId,
}) {
  final byId = {for (final style in styles) style.id: style};
  final entries = [
    for (final record in records)
      if ((styleId == null || record.styleId == styleId) &&
          record.message.trim().isNotEmpty)
        BookletHistoryEntry(record, byId[record.styleId]),
  ];
  int day(DateTime date) => date.year * 10000 + date.month * 100 + date.day;
  entries.sort((a, b) {
    final date = day(b.record.date).compareTo(day(a.record.date));
    return date != 0 ? date : a.record.id.compareTo(b.record.id);
  });
  return entries;
}
