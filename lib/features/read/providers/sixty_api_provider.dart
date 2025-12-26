import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/services/network/api_client.dart';

// 60s API 基础客户端
final sixtyApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: 'https://60s.viki.moe');
});

typedef Json = Map<String, dynamic>;

// ---------------- 周期资讯 ----------------
final sixtySecondsProvider = FutureProvider.family<Json, String?>(
  (ref, date) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/60s', queryParams: {
      if (date != null && date.isNotEmpty) 'date': date,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

final aiNewsProvider = FutureProvider.family<Json, String?>(
  (ref, date) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/ai-news', queryParams: {
      if (date != null && date.isNotEmpty) 'date': date,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

final bingWallpaperProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bing', queryParams: {
    'encoding': 'json',
  });
  return (resp.data as Json)['data'] as Json;
});

final todayInHistoryProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/today-in-history', queryParams: {
    'encoding': 'json',
  });
  return (resp.data as Json)['data'] as Json;
});

final epicGamesProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/epic', queryParams: {
    'encoding': 'json',
  });
  return (resp.data as Json)['data'] as List<dynamic>;
});

// ---------------- 实用功能 ----------------
final moyuDailyProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/moyu', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final lyricSearchProvider = FutureProvider.family<Json, String>(
  (ref, query) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/lyric', queryParams: {
      'query': query,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

final baikeEntryProvider = FutureProvider.family<Json, String>(
  (ref, word) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/baike', queryParams: {
      'word': word,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

final healthAnalysisProvider = FutureProvider.family<Json, ({int height, int weight, int age, String gender})>(
  (ref, params) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/health', queryParams: {
      'height': params.height,
      'weight': params.weight,
      'age': params.age,
      'gender': params.gender,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

// ---------------- 热门榜单 ----------------
final dongchediHotProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/dongchedi', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as List<dynamic>;
});

final maoyanAllBoxOfficeProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/maoyan/all/movie', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeMovieProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/maoyan/realtime/movie', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeTvProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/maoyan/realtime/tv', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeWebProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/maoyan/realtime/web', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

// ---------------- 消遣娱乐 ----------------
final changyaAudioProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/changya');
  return (resp.data as Json)['data'] as Json;
});

final hitokotoProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/hitokoto', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final duanziProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/duanzi', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final fabingProvider = FutureProvider.family<Json, String?>(
  (ref, name) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/fabing', queryParams: {
      if (name != null && name.isNotEmpty) 'name': name,
      'encoding': 'json',
    });
    return (resp.data as Json)['data'] as Json;
  },
);

final kfcCopyProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/kfc', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});

final dadJokeProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/dad-joke', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'] as Json;
});
