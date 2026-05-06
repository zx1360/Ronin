import 'dart:io';

import 'package:flutter/services.dart';

/// 自签证书信任管理 (Desktop 端)
///
/// 加载 assets/cert/server.crt 并配置全局 HttpOverrides，
/// 使 Image.network 等组件也能访问自签 HTTPS 服务器。
class CertTrust {
  CertTrust._();

  static SecurityContext? _securityContext;

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
    return client;
  }
}
