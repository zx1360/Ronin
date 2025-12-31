import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_client.dart';

// ---------------- 周期资讯 ----------------
final sixtySecondsProvider = FutureProvider.family<Json, String?>((
  ref,
  date,
) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/60s',
    queryParams: {
      if (date != null && date.isNotEmpty) 'date': date,
      'encoding': 'json',
    },
  );
  return (resp.data as Json)['data'] as Json;
});

final aiNewsProvider = FutureProvider.family<Json, String?>((ref, _date) async {
  final client = ref.read(sixtyApiClientProvider);
  Response resp;
  try {
    resp = await client.get('/v2/ai-news', queryParams: {'encoding': 'json'});
  } catch (_) {
    resp = await client.get('/v2/ai_news', queryParams: {'encoding': 'json'});
  }
  final data = (resp.data as Json)['data'];
  return (data is Map<String, dynamic>) ? data : {'news': data};
});

final bingWallpaperProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bing', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final todayInHistoryProvider = FutureProvider.family<Json, String?>((
  ref,
  date,
) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/today-in-history',
    queryParams: {
      'encoding': 'json',
      if (date != null && date.isNotEmpty) 'date': date,
    },
  );
  return (resp.data as Json)['data'] as Json;
});

final epicGamesProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/epic', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as List<dynamic>;
});
