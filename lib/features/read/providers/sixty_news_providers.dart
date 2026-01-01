import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
part 'sixty_news_providers.g.dart';

// ---------------- 周期资讯 ----------------
@riverpod
Future<Json> sixtySeconds(SixtySecondsRef ref, String? date) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/60s',
    queryParams: {
      if (date != null && date.isNotEmpty) 'date': date,
      'encoding': 'json',
    },
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> aiNews(AiNewsRef ref, String? date) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/ai-news', queryParams: {'encoding': 'json', 'all': '1'});
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> bingWallpaper(BingWallpaperRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bing', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<List<dynamic>> epicGames(EpicGamesRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/epic', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as List<dynamic>;
}
