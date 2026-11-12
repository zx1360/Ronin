import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/core/services/network/api_client.dart';

part 'sixty_api_provider.g.dart';

typedef Json = Map<String, dynamic>;

@Riverpod(keepAlive: true)
SixtyApiClient sixtyApiClient(Ref ref) {
  final client = SixtyApiClient();
  ref.onDispose(client.close);
  return client;
}

class SixtyApiClient extends ApiClient {
  SixtyApiClient() : super(baseUrl: '', retryConnections: false);

  static const _hosts = ['https://60s.crystelf.top', 'https://60s.okbaike.com'];
  static const _rateLimited = ApiException('资讯服务请求过多，请稍后重试', statusCode: 429);
  final _retryAfter = <String, DateTime>{};

  Future<T> fetch<T extends Object>(
    String endpoint,
    T? Function(Object?) decode, {
    required CancelToken cancelToken,
    Map<String, String> params = const {},
  }) async {
    ApiException? failure;
    for (final host in _hosts) {
      final retryAt = _retryAfter[host];
      if (retryAt != null && retryAt.isAfter(DateTime.now())) {
        failure ??= _rateLimited;
        continue;
      }
      try {
        final response = await get(
          '$host/v2/$endpoint',
          queryParams: {'encoding': 'json', ...params},
          cancelToken: cancelToken,
        );
        final body = response.data;
        if (body is Json) {
          final code = body['code'];
          if (code == 429 || code == '429') {
            _retryAfter[host] = _nextAttempt(response.headers);
            failure = _rateLimited;
            continue;
          }
          if (code == null || code == 200 || code == '200') {
            final data = decode(body['data']);
            if (data != null) return data;
          }
          if (code == 404 || code == '404') {
            failure = const ApiException('资讯服务暂无这条内容', statusCode: 404);
            continue;
          }
        }
        failure = const ApiException('资讯服务返回了无法读取的内容');
      } on DioException catch (error) {
        if (cancelToken.isCancelled) throw ApiClient.mapError(error);
        final response = error.response;
        if (response?.statusCode == 429) {
          _retryAfter[host] = _nextAttempt(response!.headers);
          failure = _rateLimited;
        } else if (response?.statusCode == 404) {
          failure = const ApiException('资讯服务暂无这条内容', statusCode: 404);
        } else {
          failure = ApiClient.mapError(error);
        }
      }
    }
    throw failure ?? const ApiException('资讯服务暂时不可用');
  }

  DateTime _nextAttempt(Headers headers) {
    final value = headers['retry-after']?.firstOrNull;
    final now = DateTime.now();
    if (value != null) {
      final seconds = int.tryParse(value);
      if (seconds != null && seconds >= 0) {
        return now.add(Duration(seconds: seconds));
      }
      try {
        return HttpDate.parse(value);
      } on HttpException {
        // 无效响应头使用默认冷却时间。
      }
    }
    return now.add(const Duration(minutes: 1));
  }
}

Future<T> _load<T extends Object>(
  Ref ref,
  String endpoint,
  T? Function(Object?) decode, {
  Map<String, String> params = const {},
}) async {
  final client = ref.watch(sixtyApiClientProvider);
  final token = CancelToken();
  ref.onDispose(token.cancel);
  final result = await client.fetch(
    endpoint,
    decode,
    cancelToken: token,
    params: params,
  );
  if (!token.isCancelled) {
    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 2), link.close);
    ref.onDispose(timer.cancel);
  }
  return result;
}

List<Json>? _list(Object? value) {
  if (value is Json) value = value['list'] ?? value['items'];
  if (value is! List) return null;
  final rows = value.whereType<Json>().toList();
  return rows.isEmpty && value.isNotEmpty ? null : rows;
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

Future<String> _sentence(
  Ref ref,
  String endpoint,
  String key, {
  Map<String, String> params = const {},
}) => _load(
  ref,
  endpoint,
  (value) => value is Json ? _text(value[key]) : null,
  params: params,
);

@riverpod
Future<Json> sixtySeconds(Ref ref, String? date) => _load(
  ref,
  '60s',
  (value) =>
      value is Json &&
          value['news'] is List &&
          (date == null || date.isEmpty || value['date'] == date)
      ? value
      : null,
  params: {if (date != null && date.isNotEmpty) 'date': date},
);

@riverpod
Future<Json> bingWallpaper(Ref ref) => _load(
  ref,
  'bing',
  (value) =>
      value is Json &&
          (_text(value['cover']) != null || _text(value['cover_4k']) != null)
      ? value
      : null,
);

@riverpod
Future<List<Json>> epicGames(Ref ref) => _load(ref, 'epic', _list);

@riverpod
Future<List<Json>> toutiaoHot(Ref ref) => _load(ref, 'toutiao', _list);

@riverpod
Future<List<Json>> zhihuHot(Ref ref) => _load(ref, 'zhihu', _list);

@riverpod
Future<List<Json>> baiduTieba(Ref ref) => _load(ref, 'baidu/tieba', _list);

@riverpod
Future<String> hitokoto(Ref ref) => _sentence(ref, 'hitokoto', 'hitokoto');

@riverpod
Future<String> duanzi(Ref ref) => _sentence(ref, 'duanzi', 'duanzi');

@riverpod
Future<String> fabing(Ref ref, String? person) => _sentence(
  ref,
  'fabing',
  'saying',
  params: {if (person != null && person.isNotEmpty) 'name': person},
);

@riverpod
Future<String> kfcCopy(Ref ref) => _sentence(ref, 'kfc', 'kfc');

@riverpod
Future<String> dadJoke(Ref ref) => _sentence(ref, 'dad-joke', 'content');
