import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/booklet/models/record.dart';
import 'package:torrid/features/booklet/models/style.dart';
import 'package:torrid/features/booklet/providers/routine_service_provider.dart';
import 'package:torrid/features/booklet/storage/booklet_store.dart';

final styleStreamProvider = StreamProvider.autoDispose<List<Style>>(
  (ref) => ref.watch(bookletStoreProvider).watchStyles(),
);

final recordStreamProvider = StreamProvider.autoDispose<List<Record>>(
  (ref) => ref.watch(bookletStoreProvider).watchRecords(),
);

final allStylesProvider = Provider.autoDispose<List<Style>>((ref) {
  final styles = ref.watch(styleStreamProvider);
  if (styles.hasError) throw styles.error!;
  return stylesWithStats(styles.value ?? [], ref.watch(allRecordsProvider));
});

final allRecordsProvider = Provider.autoDispose<List<Record>>((ref) {
  final records = ref.watch(recordStreamProvider);
  if (records.hasError) throw records.error!;
  return records.value ?? [];
});
