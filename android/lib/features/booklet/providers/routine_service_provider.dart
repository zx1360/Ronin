import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/booklet/storage/booklet_store.dart';

final bookletStoreProvider = Provider(
  (ref) => BookletStore(ref.watch(appDatabaseProvider)),
);
