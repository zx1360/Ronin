import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
part 'sixty_utils_providers.g.dart';

// ---------------- 实用功能 ----------------
@riverpod
Future<Json> moyuDaily(MoyuDailyRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/moyu', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> lyricSearch(LyricSearchRef ref, String query) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/lyric',
    queryParams: {'query': query, 'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}
