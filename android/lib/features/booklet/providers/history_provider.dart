import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/models/history_entry.dart';
import 'package:torrid/features/booklet/providers/data_source_provider.dart';

part 'history_provider.g.dart';

@riverpod
Future<List<BookletHistoryEntry>> bookletHistory(
  BookletHistoryRef ref, {
  String? styleId,
  bool onlyMessages = true,
}) async {
  final records = ref.watch(recordStreamProvider.future);
  final styles = ref.watch(styleStreamProvider.future);
  return buildBookletHistory(
    await records,
    await styles,
    styleId: styleId,
    onlyMessages: onlyMessages,
  );
}
