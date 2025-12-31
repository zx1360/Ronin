import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/read/providers/sixty_client.dart';
part 'sixty_hot_providers.g.dart';

// ---------------- 热门榜单 ----------------
@riverpod
Future<List<dynamic>> dongchediHot(DongchediHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/dongchedi',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as List<dynamic>;
}

@riverpod
Future<Json> maoyanAllBoxOffice(MaoyanAllBoxOfficeRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/all/movie',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> maoyanRealtimeMovie(MaoyanRealtimeMovieRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/movie',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> maoyanRealtimeTv(MaoyanRealtimeTvRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/tv',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

@riverpod
Future<Json> maoyanRealtimeWeb(MaoyanRealtimeWebRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/maoyan/realtime/web',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'] as Json;
}

// 反选补充的热门榜单
@riverpod
Future<dynamic> toutiaoHot(ToutiaoHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/toutiao',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> weiboHot(WeiboHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/weibo', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> zhihuHot(ZhihuHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/zhihu', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> hackerNews(HackerNewsRef ref, String kind) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/hacker-news/$kind',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> baiduHot(BaiduHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/hot',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> baiduTeleplay(BaiduTeleplayRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/teleplay',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> baiduTieba(BaiduTiebaRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/baidu/tieba',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> ncmRankList(NcmRankListRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/ncm-rank/list',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> biliHot(BiliHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/bili', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> douyinHot(DouyinHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/douyin',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> quarkHot(QuarkHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/quark', queryParams: {'encoding': 'json'});
  return (resp.data as Json)['data'];
}

@riverpod
Future<dynamic> rednoteHot(RednoteHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get(
    '/v2/rednote',
    queryParams: {'encoding': 'json'},
  );
  return (resp.data as Json)['data'];
}
