import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_client.dart';

// ---------------- 实用功能 ----------------
final moyuDailyProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/moyu', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final lyricSearchProvider = FutureProvider.family<Json, String>((
  ref,
  query,
) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/lyric',
    queryParams: {'query': query, 'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final baikeEntryProvider = FutureProvider.family<Json, String>((
  ref,
  word,
) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baike',
    queryParams: {'word': word, 'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final healthAnalysisProvider =
    FutureProvider.family<
      Json,
      ({int height, int weight, int age, String gender})
    >((ref, params) async {
      final client = ref.read(sixtyApiClientProvider);
      final resp = await client.get(
        '/v2/health',
        queryParams: {
          'height': params.height,
          'weight': params.weight,
          'age': params.age,
          'gender': params.gender,
          'encoding': 'json',
        },
      );
      return (resp.data as Json)['data'] as Json;
    });
