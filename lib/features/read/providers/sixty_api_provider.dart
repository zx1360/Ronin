import 'package:dio/dio.dart';
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
  (ref, _date) async {
    final client = ref.read(sixtyApiClientProvider);
    Response resp;
    try {
      resp = await client.get('/v2/ai-news', queryParams: {
        'encoding': 'json',
      });
    } catch (_) {
      resp = await client.get('/v2/ai_news', queryParams: {
        'encoding': 'json',
      });
    }
    final data = (resp.data as Json)['data'];
    return (data is Map<String, dynamic>) ? data : {'news': data};
  },
);

final bingWallpaperProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bing', queryParams: {
    'encoding': 'json',
  });
  return (resp.data as Json)['data'] as Json;
});

final todayInHistoryProvider = FutureProvider.family<Json, String?>(
  (ref, date) async {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.get('/v2/today-in-history', queryParams: {
      'encoding': 'json',
      if (date != null && date.isNotEmpty) 'date': date, // 若服务端支持则生效
    });
    return (resp.data as Json)['data'] as Json;
  },
);

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

// 反选补充的热门榜单
final toutiaoHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/toutiao', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final weiboHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/weibo', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final zhihuHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/zhihu', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final hackerNewsProvider = FutureProvider.family<dynamic, String>((ref, kind) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/hacker-news/$kind', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final baiduHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/baidu/hot', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final baiduTeleplayProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/baidu/teleplay', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final baiduTiebaProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/baidu/tieba', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final ncmRankListProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/ncm-rank/list', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final biliHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bili', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final douyinHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/douyin', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final quarkHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/quark', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final rednoteHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/rednote', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});


// ---------------- 消遣娱乐 ----------------
final changyaAudioProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/changya', queryParams: {'encoding': 'json'});
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
