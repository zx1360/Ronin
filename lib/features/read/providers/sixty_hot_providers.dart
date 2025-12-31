import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/read/providers/sixty_client.dart';

// ---------------- 热门榜单 ----------------
final dongchediHotProvider = FutureProvider<List<dynamic>>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/dongchedi',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as List<dynamic>;
});

final maoyanAllBoxOfficeProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/all/movie',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeMovieProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/movie',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeTvProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/tv',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

final maoyanRealtimeWebProvider = FutureProvider<Json>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/web',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
});

// 反选补充的热门榜单
final toutiaoHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/toutiao',
    queryParams: {'encoding': 'json'},
  );
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

final hackerNewsProvider = FutureProvider.family<dynamic, String>((
  ref,
  kind,
) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/hacker-news/$kind',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final baiduHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/hot',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final baiduTeleplayProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/teleplay',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final baiduTiebaProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/tieba',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final ncmRankListProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/ncm-rank/list',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final biliHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bili', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final douyinHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/douyin',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});

final quarkHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/quark', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
});

final rednoteHotProvider = FutureProvider<dynamic>((ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/rednote',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
});
