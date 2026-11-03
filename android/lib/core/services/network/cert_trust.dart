import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

<<<<<<< HEAD
/// Dart 网络请求与 Android 播放器共用内置后端证书。
class CertTrust {
  CertTrust._();
=======
class CertTrust extends HttpOverrides {
  static const _prefix = 'tls_sha256:';
  static const _legacyPin = String.fromEnvironment('MONARCH_CERT_SHA256');
  static final _fingerprint = RegExp(r'^[a-f0-9]{64}$');
>>>>>>> 1fc83d9 (重构瘦身+分发性.)

  static void init() => HttpOverrides.global = CertTrust();

<<<<<<< HEAD
  /// 初始化: 从 assets 加载证书, 设置全局 HttpOverrides.
  /// 应在 main() 中 WidgetsFlutterBinding.ensureInitialized() 之后调用.
  static Future<void> init() async {
    if (_securityContext != null) return;
    final certBytes = await rootBundle.load(
      'android/app/src/main/res/raw/server.crt',
    );
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
=======
  static String pinFor(String address) =>
      PrefsService().prefs.getString('$_prefix$address') ?? '';

  static Future<void> savePin(String address, String value) async {
    final pin = value.replaceAll(RegExp(r'[:\s]'), '').toLowerCase();
    if (pin.isNotEmpty && !_fingerprint.hasMatch(pin)) {
      throw const FormatException('请输入 64 位十六进制 SHA-256 指纹');
    }
    if (!await PrefsService().prefs.setString('$_prefix$address', pin)) {
      throw StateError('无法保存证书指纹');
    }
>>>>>>> 1fc83d9 (重构瘦身+分发性.)
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) {
        final pin = pinFor(Uri(host: host, port: port).authority);
        final now = DateTime.now();
        return now.isAfter(cert.startValidity) &&
            now.isBefore(cert.endValidity) &&
            sha256.convert(cert.der).toString() ==
                (pin.isEmpty ? _legacyPin : pin);
      };
  }

  static IOHttpClientAdapter createAdapter() =>
      IOHttpClientAdapter(createHttpClient: HttpClient.new);

  static Dio createDio({BaseOptions? options}) =>
      Dio(options)..httpClientAdapter = createAdapter();
}
