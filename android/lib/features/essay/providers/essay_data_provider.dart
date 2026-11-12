import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/models/label.dart';
import 'package:torrid/features/essay/services/essay_store.dart';

final essayStoreProvider = Provider(
  (ref) => EssayStore(ref.watch(appDatabaseProvider)),
);

final essayStreamProvider = StreamProvider.autoDispose<List<Essay>>(
  (ref) => ref.watch(essayStoreProvider).watchEssays(),
);

final labelStreamProvider = StreamProvider.autoDispose<List<Label>>(
  (ref) => ref.watch(essayStoreProvider).watchLabels(),
);

final essayByIdProvider = StreamProvider.autoDispose.family<Essay?, String>(
  (ref, id) => ref.watch(essayStoreProvider).watchEssay(id),
);
