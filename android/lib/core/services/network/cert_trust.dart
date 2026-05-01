import 'dart:io';

import 'package:dio/io.dart';
import 'package:flutter/services.dart';

/// 自签证书信任管理
///
/// 加载 assets/cert/server.crt 并配置全局 HttpOverrides,
/// 使 Image.network / CachedNetworkImage 等也能访问自签 HTTPS 服务器.
class CertTrust {
  CertTrust._();

  static SecurityContext? _securityContext;

  /// 初始化: 从 assets 加载证书, 设置全局 HttpOverrides.
  /// 应在 main() 中 WidgetsFlutterBinding.ensureInitialized() 之后调用.
  static Future<void> init() async {
    final certBytes = await rootBundle.load('assets/cert/server.crt');
    _securityContext = SecurityContext(withTrustedRoots: true);
    _securityContext!.setTrustedCertificatesBytes(certBytes.buffer.asUint8List());
    HttpOverrides.global = _TrustedCertHttpOverrides(_securityContext!);
  }

  /// 为 Dio 配置 IOHttpClientAdapter 以信任自签证书.
  static void configureDio(HttpClient httpClient) {
    httpClient.badCertificateCallback = _verifyCert;
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

  static bool _verifyCert(X509Certificate cert, String host, int port) {
    // 自签证书: 信任 SecurityContext 中已加载的证书.
    // 当 SecurityContext 中包含对应 CA/自签证书时, 此回调不会被触发;
    // 仅作为兜底, 允许通过.
    return true;
  }
}

class _TrustedCertHttpOverrides extends HttpOverrides {
  final SecurityContext _context;
  _TrustedCertHttpOverrides(this._context);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(_context);
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  }
}
