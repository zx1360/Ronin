import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// 自签证书信任管理 (Desktop 端)
///
/// 加载 assets/cert/server.crt 并配置全局 HttpOverrides，
/// 使 Image.network 等组件也能访问自签 HTTPS 服务器，
/// 同时为所有请求自动注入 X-API-Key (若已设置)。
class CertTrust {
  CertTrust._();

  static SecurityContext? _securityContext;
  static String? _apiKey;

  /// 获取当前全局 API Key。由 OpsSettingsController 在变更时同步。
  static String? get apiKey => _apiKey;

  /// 更新全局 API Key，供 Image.network 等原生请求自动携带。
  static void setApiKey(String? key) {
    _apiKey = (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  /// 初始化: 从 assets 加载证书, 设置全局 HttpOverrides。
  /// 应在 main() 中 WidgetsFlutterBinding.ensureInitialized() 之后调用。
  static Future<void> init() async {
    final certBytes = await rootBundle.load('assets/cert/server.crt');
    _securityContext = SecurityContext(withTrustedRoots: false);
    _securityContext!
        .setTrustedCertificatesBytes(certBytes.buffer.asUint8List());
    HttpOverrides.global = _TrustedCertHttpOverrides(_securityContext!);
  }
}

class _TrustedCertHttpOverrides extends HttpOverrides {
  final SecurityContext _context;
  _TrustedCertHttpOverrides(this._context);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(_context);
    client.badCertificateCallback = (cert, host, port) => true;
    return _AuthHttpClient(client);
  }
}

/// 包装原生 HttpClient，在每次 openUrl 时自动注入 X-API-Key。
/// Dart SDK 中 getUrl / postUrl / putUrl / deleteUrl / patchUrl / headUrl
/// 均委托给 openUrl，因此只覆盖 openUrl 即可覆盖所有请求方法。
class _AuthHttpClient implements HttpClient {
  final HttpClient _inner;

  _AuthHttpClient(this._inner);

  // --- 核心拦截点 (openUrl / getUrl 等被 Image.network 调用) ---

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final req = await _inner.openUrl(method, url);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  // --- 新 API (host/port/path 签名) ---

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) async {
    final req = await _inner.open(method, host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async {
    final req = await _inner.get(host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async {
    final req = await _inner.post(host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async {
    final req = await _inner.put(host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async {
    final req = await _inner.delete(host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async {
    final req = await _inner.patch(host, port, path);
    _injectApiKey(req);
    return req;
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) async {
    final req = await _inner.head(host, port, path);
    _injectApiKey(req);
    return req;
  }

  void _injectApiKey(HttpClientRequest req) {
    final key = CertTrust.apiKey;
    if (key != null) {
      req.headers.set('X-API-Key', key);
    }
  }

  // --- 属性委托 ---

  @override
  Duration get connectionTimeout => _inner.connectionTimeout ?? Duration.zero;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration? value) {
    if (value != null) _inner.idleTimeout = value;
  }

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) =>
      _inner.authenticateProxy = f;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
