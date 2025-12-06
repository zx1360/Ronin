import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/booklet/providers/routine_notifier_provider.dart';
import 'package:torrid/features/essay/providers/essay_notifier_provider.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';
import 'package:torrid/services/debug/logging_service.dart';

part 'sync_service.g.dart';

@riverpod
Future<void> syncBooklet(SyncBookletRef ref) async {
  try {
    final resp = await ref.read(fetcherProvider(path: "/api/user-data/sync/booklet").future);
    if (resp == null || resp.statusCode != 200) {
      AppLogger().error("syncBooklet出错");
    } else {
      await ref.read(routineServiceProvider.notifier).syncData(resp.data);
    }
  } catch (e) {
    AppLogger().error("syncBooklet出错: $e");
  }
}

@riverpod
Future<void> syncEssay(SyncEssayRef ref) async {
  try {
    final resp = await ref.read(fetcherProvider(path: "/api/user-data/sync/essay").future);
    if (resp == null || resp.statusCode != 200) {
      AppLogger().error("syncEssay失败");
    } else {
      await ref.read(essayServiceProvider.notifier).syncData(resp.data);
    }
  } catch (e) {
    AppLogger().error("syncEssay出错: $e");
  }
}
