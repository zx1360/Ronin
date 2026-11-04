import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';

part 'sixty_api_provider.g.dart';

@Riverpod(keepAlive: true)
ApiClient sixtyApiClient(SixtyApiClientRef ref) {
  final client = ApiClient(baseUrl: 'https://60s.viki.moe');
  ref.onDispose(client.close);
  return client;
}

typedef Json = Map<String, dynamic>;

Future<T> _fetchData<T>(
  ApiClient client,
  String endpoint, [
  Map<String, String> params = const {},
]) async {
  final response = await client.get(
    '/v2/$endpoint',
    queryParams: {'encoding': 'json', ...params},
  );
  return (response.data as Json)['data'] as T;
}

@riverpod
Future<Json> sixtySeconds(SixtySecondsRef ref, String? date) => _fetchData(
  ref.watch(sixtyApiClientProvider),
  '60s',
  {if (date != null && date.isNotEmpty) 'date': date},
);

@riverpod
Future<Json> bingWallpaper(BingWallpaperRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'bing');

@riverpod
Future<List<dynamic>> epicGames(EpicGamesRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'epic');

@riverpod
Future<dynamic> toutiaoHot(ToutiaoHotRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'toutiao');

@riverpod
Future<dynamic> zhihuHot(ZhihuHotRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'zhihu');

@riverpod
Future<dynamic> baiduTieba(BaiduTiebaRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'baidu/tieba');

@riverpod
Future<Json> hitokoto(HitokotoRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'hitokoto');

@riverpod
Future<Json> duanzi(DuanziRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'duanzi');

@riverpod
Future<Json> fabing(FabingRef ref, String? person) => _fetchData(
  ref.watch(sixtyApiClientProvider),
  'fabing',
  {if (person != null && person.isNotEmpty) 'name': person},
);

@riverpod
Future<Json> kfcCopy(KfcCopyRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'kfc');

@riverpod
Future<Json> dadJoke(DadJokeRef ref) =>
    _fetchData(ref.watch(sixtyApiClientProvider), 'dad-joke');
