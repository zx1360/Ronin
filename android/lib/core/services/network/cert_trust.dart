import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 自签证书信任管理
///
/// 加载 assets/cert/server.crt 并配置全局 HttpOverrides,
/// 使 Image.network / CachedNetworkImage 等也能访问自签 HTTPS 服务器.
class CertTrust {
  CertTrust._();

  static SecurityContext? _securityContext;
  static List<int>? _trustedCertificate;

  /// 初始化: 从 assets 加载证书, 设置全局 HttpOverrides.
  /// 应在 main() 中 WidgetsFlutterBinding.ensureInitialized() 之后调用.
  static Future<void> init() async {
    if (_securityContext != null) return;
    final certBytes = await rootBundle.load('assets/cert/server.crt');
    final bytes = certBytes.buffer.asUint8List(
      certBytes.offsetInBytes,
      certBytes.lengthInBytes,
    );
    final pem = utf8.decode(bytes);
    final body = RegExp(
      r'-----BEGIN CERTIFICATE-----([\s\S]+?)-----END CERTIFICATE-----',
    ).firstMatch(pem)?.group(1);
    if (body == null) throw const FormatException('后端证书格式无效');
    final trusted = base64Decode(body.replaceAll(RegExp(r'\s'), ''));
    final context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(bytes);
    _trustedCertificate = trusted;
    _securityContext = context;
    HttpOverrides.global = _TrustedCertHttpOverrides(context);
  }

  /// 创建已配置信任的 IOHttpClientAdapter, 供 Dio 使用.
  static IOHttpClientAdapter createAdapter() {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient(context: _securityContext);
        client.badCertificateCallback = _verifyCert;
        return client;
      },
    );
  }

  /// 创建预配置的 Dio 实例 (已信任自签证书).
  ///
  /// 适用于需要在 ApiClient 之外使用 Dio 的场景 (如连接测试、外部资源加载),
  /// 确保自签证书信任配置一致.
  static Dio createDio({BaseOptions? options}) {
    final dio = Dio(options ?? BaseOptions());
    dio.httpClientAdapter = createAdapter();
    return dio;
  }

  static bool _verifyCert(X509Certificate cert, String host, int port) {
    return _trustedCertificate != null &&
        listEquals(cert.der, _trustedCertificate);
  }
}

class _TrustedCertHttpOverrides extends HttpOverrides {
  final SecurityContext _context;
  _TrustedCertHttpOverrides(this._context);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context ?? _context);
    client.badCertificateCallback = CertTrust._verifyCert;
    return client;
  }
}
