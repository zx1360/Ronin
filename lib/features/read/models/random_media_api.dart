import 'dart:io';

import 'package:dio/dio.dart';

/// 模拟常规移动浏览器的 User-Agent
const String kUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36';

// ────────────────────────────────────────────
// 模型定义
// ────────────────────────────────────────────

enum ApiResponseType { redirect302, json }

/// 可选参数的单项
class ApiParamOption {
  final String value;
  final String label;
  const ApiParamOption(this.value, this.label);
}

/// API 可选参数
class ApiParam {
  final String key;
  final String label;

  /// null → 文本输入框, 非 null → 下拉选择
  final List<ApiParamOption>? options;
  final String defaultValue;
  final String? hint;

  const ApiParam({
    required this.key,
    required this.label,
    this.options,
    this.defaultValue = '',
    this.hint,
  });

  bool get isTextInput => options == null;
}

/// 单个 API 源
class RandomMediaSource {
  final String label;
  final String apiUrl;
  final ApiResponseType responseType;

  /// 简单 JSON 提取: response[key]
  final String? jsonUrlKey;

  /// 嵌套 JSON 提取: 按路径逐级索引, 支持 {paramKey} 占位符
  final List<String>? jsonUrlPath;

  final List<ApiParam> params;

  /// 加载 / 下载图片时需要的额外请求头
  final Map<String, String>? extraHeaders;

  const RandomMediaSource({
    required this.label,
    required this.apiUrl,
    required this.responseType,
    this.jsonUrlKey,
    this.jsonUrlPath,
    this.params = const [],
    this.extraHeaders,
  });
}

/// API 源分组（同一站点的多个端点）
class MediaApiGroup {
  final String id;
  final String name;
  final List<RandomMediaSource> sources;

  const MediaApiGroup({
    required this.id,
    required this.name,
    required this.sources,
  });
}

// ────────────────────────────────────────────
// 图片 API 源
// ────────────────────────────────────────────

const kImageGroups = <MediaApiGroup>[
  // ── czl.net ──
  MediaApiGroup(id: 'czl', name: 'czl 随机', sources: [
    RandomMediaSource(label: '全部图片', apiUrl: 'https://random-api.czl.net/pic/all', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '普通图片', apiUrl: 'https://random-api.czl.net/pic/normal', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: 'AI 图片', apiUrl: 'https://random-api.czl.net/pic/ai', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '二次元', apiUrl: 'https://random-api.czl.net/pic/ecy', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '加载图', apiUrl: 'https://random-api.czl.net/pic/loading', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '背景图', apiUrl: 'https://random-api.czl.net/pic/czlwb', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '风景', apiUrl: 'https://random-api.czl.net/pic/fj', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '美女', apiUrl: 'https://random-api.czl.net/pic/truegirl', responseType: ApiResponseType.redirect302),
  ]),

  // ── xxapi.cn ──
  MediaApiGroup(id: 'xxapi', name: 'xxapi 4K 壁纸', sources: [
    RandomMediaSource(
      label: '4K 壁纸',
      apiUrl: 'https://v2.xxapi.cn/api/random4kPic?return=json',
      responseType: ApiResponseType.json,
      jsonUrlKey: 'data',
      params: [
        ApiParam(key: 'type', label: '类型', defaultValue: 'acg', options: [
          ApiParamOption('acg', '二次元'),
          ApiParamOption('wallpaper', '风景壁纸'),
        ]),
      ],
    ),
  ]),

  // ── ZiChen ACG ──
  MediaApiGroup(id: 'zichen', name: 'ZiChen ACG', sources: [
    RandomMediaSource(label: 'ACG 二次元', apiUrl: 'https://app.zichen.zone/api/acg/api.php', responseType: ApiResponseType.redirect302),
  ]),

  // ── paulzzh 东方 Project ──
  MediaApiGroup(id: 'paulzzh', name: '东方 Project', sources: [
    RandomMediaSource(
      label: '东方随机',
      apiUrl: 'https://img.paulzzh.com/touhou/random?type=json',
      responseType: ApiResponseType.json,
      jsonUrlKey: 'url',
      extraHeaders: {'Referer': 'https://img.paulzzh.com/'},
      params: [
        ApiParam(key: 'site', label: '来源', defaultValue: 'konachan', options: [
          ApiParamOption('konachan', 'Konachan'),
          ApiParamOption('yandere', 'Yande.re'),
          ApiParamOption('all', '全部'),
        ]),
        ApiParam(key: 'size', label: '方向', defaultValue: 'pc', options: [
          ApiParamOption('pc', '横屏'),
          ApiParamOption('wap', '竖屏'),
          ApiParamOption('all', '全部'),
        ]),
      ],
    ),
  ]),

  // ── Lolicon Pixiv ──
  MediaApiGroup(id: 'lolicon', name: 'Lolicon Pixiv', sources: [
    RandomMediaSource(
      label: 'Pixiv 随机',
      apiUrl: 'https://api.lolicon.app/setu/v2?r18=0&num=1',
      responseType: ApiResponseType.json,
      jsonUrlPath: ['data', '0', 'urls', '{size}'],
      params: [
        ApiParam(key: 'size', label: '图片规格', defaultValue: 'regular', options: [
          ApiParamOption('original', '原图'),
          ApiParamOption('regular', '常规'),
          ApiParamOption('small', '小图'),
        ]),
        ApiParam(key: 'excludeAI', label: '排除 AI', defaultValue: 'false', options: [
          ApiParamOption('false', '不排除'),
          ApiParamOption('true', '排除'),
        ]),
        ApiParam(key: 'tag', label: '标签', hint: '可选，如: 风景|壁纸'),
      ],
    ),
  ]),

  // ── seovx.com ──
  MediaApiGroup(id: 'seovx', name: 'seovx 随机', sources: [
    RandomMediaSource(label: '随机美图', apiUrl: 'https://cdn.seovx.com/', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '随机动漫', apiUrl: 'https://cdn.seovx.com/ha/', responseType: ApiResponseType.redirect302),
  ]),

  // ── alcy.cc ──
  MediaApiGroup(id: 'alcy', name: 'alcy 图片', sources: [
    RandomMediaSource(label: '二次元 (自适应)', apiUrl: 'https://t.alcy.cc/ycy', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '萌版 (自适应)', apiUrl: 'https://t.alcy.cc/moez', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: 'AI 绘画 (自适应)', apiUrl: 'https://t.alcy.cc/ai', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '原神 (自适应)', apiUrl: 'https://t.alcy.cc/ysz', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: 'PC 横图', apiUrl: 'https://t.alcy.cc/pc', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '萌版横图', apiUrl: 'https://t.alcy.cc/moe', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '风景横图', apiUrl: 'https://t.alcy.cc/fj', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '移动竖图', apiUrl: 'https://t.alcy.cc/mp', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: 'AI 竖图', apiUrl: 'https://t.alcy.cc/aimp', responseType: ApiResponseType.redirect302),
    RandomMediaSource(label: '头像方图', apiUrl: 'https://t.alcy.cc/tx', responseType: ApiResponseType.redirect302),
  ]),

  // ── 岁月小筑 xjh.me ──
  MediaApiGroup(id: 'xjh', name: '岁月小筑', sources: [
    RandomMediaSource(
      label: '随机图片',
      apiUrl: 'https://img.xjh.me/random_img.php?return=json',
      responseType: ApiResponseType.json,
      jsonUrlKey: 'imgurl',
      params: [
        ApiParam(key: 'type', label: '类型', defaultValue: '', options: [
          ApiParamOption('', '全部'),
          ApiParamOption('bg', '背景'),
        ]),
        ApiParam(key: 'ctype', label: '背景分类', defaultValue: '', options: [
          ApiParamOption('', '全部'),
          ApiParamOption('acg', '动漫'),
          ApiParamOption('nature', '自然风光'),
        ]),
      ],
    ),
  ]),
];

// ────────────────────────────────────────────
// 视频 API 源
// ────────────────────────────────────────────

const kVideoGroups = <MediaApiGroup>[
  MediaApiGroup(id: 'czl', name: 'czl 随机', sources: [
    RandomMediaSource(label: '抖音艺术', apiUrl: 'https://random-api.czl.net/video/dy-art', responseType: ApiResponseType.redirect302),
  ]),
];

// ────────────────────────────────────────────
// URL 解析与下载
// ────────────────────────────────────────────

class MediaUrlResolver {
  MediaUrlResolver._();

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 10)
    ..options.receiveTimeout = const Duration(seconds: 20)
    ..options.headers = {'User-Agent': kUserAgent};

  /// 根据源配置和用户参数获取实际资源 URL
  static Future<String> fetchMediaUrl(
    RandomMediaSource source, [
    Map<String, String> params = const {},
  ]) async {
    final requestUrl = _buildRequestUrl(source, params);
    try {
      switch (source.responseType) {
        case ApiResponseType.redirect302:
          return await _resolveRedirect(requestUrl);
        case ApiResponseType.json:
          if (source.jsonUrlPath != null) {
            return await _fetchFromJsonPath(
              requestUrl, source.jsonUrlPath!, params, source.extraHeaders,
            );
          }
          return await _fetchFromJson(
            requestUrl, source.jsonUrlKey ?? 'data', source.extraHeaders,
          );
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('连接超时，请检查网络');
      }
      if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('接收数据超时');
      }
      if (e.response?.statusCode != null) {
        throw Exception('服务器错误 (${e.response!.statusCode})');
      }
      throw Exception('网络请求失败');
    }
  }

  /// 从源 URL 和用户参数构建完整请求 URL
  static String _buildRequestUrl(
    RandomMediaSource source,
    Map<String, String> params,
  ) {
    if (params.isEmpty) return source.apiUrl;
    final uri = Uri.parse(source.apiUrl);
    final allParams = Map<String, String>.from(uri.queryParameters);
    params.forEach((key, value) {
      if (value.isNotEmpty) allParams[key] = value;
    });
    return uri.replace(queryParameters: allParams).toString();
  }

  /// 使用 dart:io HttpClient 解析 302 重定向
  static Future<String> _resolveRedirect(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    client.badCertificateCallback = (_, __, ___) => true;
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = false;
      request.headers.set('User-Agent', kUserAgent);
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          return location.startsWith('http')
              ? location
              : Uri.parse(url).resolve(location).toString();
        }
      }
      return url;
    } finally {
      client.close();
    }
  }

  /// 简单 JSON: response[key]
  static Future<String> _fetchFromJson(
    String url,
    String key,
    Map<String, String>? headers,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(headers: {'User-Agent': kUserAgent, ...?headers}),
    );
    if (response.data is Map) {
      final value = (response.data as Map)[key];
      if (value is String && value.startsWith('http')) return value;
    }
    throw Exception('无法从响应中获取有效的资源地址');
  }

  /// 嵌套 JSON: 按路径逐级提取, 支持 {paramKey} 占位符替换
  static Future<String> _fetchFromJsonPath(
    String url,
    List<String> path,
    Map<String, String> params,
    Map<String, String>? headers,
  ) async {
    final response = await _dio.get(
      url,
      options: Options(headers: {'User-Agent': kUserAgent, ...?headers}),
    );
    dynamic current = response.data;
    for (var key in path) {
      if (key.startsWith('{') && key.endsWith('}')) {
        key = params[key.substring(1, key.length - 1)] ?? key;
      }
      if (current is Map) {
        if (!current.containsKey(key)) {
          throw Exception('响应中缺少字段: $key');
        }
        current = current[key];
      } else if (current is List) {
        if (current.isEmpty) throw Exception('没有找到匹配的结果');
        final index = int.tryParse(key);
        if (index != null && index < current.length) {
          current = current[index];
        } else {
          throw Exception('结果索引无效');
        }
      } else {
        throw Exception('响应格式异常');
      }
    }
    if (current is String && current.startsWith('http')) return current;
    throw Exception('无法获取有效的图片地址');
  }

  /// 下载资源字节数据
  static Future<List<int>> downloadBytes(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 60),
        headers: {'User-Agent': kUserAgent, ...?headers},
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) throw Exception('下载数据为空');
    return data;
  }
}
