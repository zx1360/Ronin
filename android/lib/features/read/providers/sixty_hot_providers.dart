import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
part 'sixty_hot_providers.g.dart';

// ---------------- 热门榜单 ----------------
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
Future<dynamic> zhihuHot(ZhihuHotRef ref) async {
  final client = ref.read(sixtyApiClientProvider);
  final resp = await client.get('/v2/zhihu', queryParams: {'encoding': 'json'});
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


