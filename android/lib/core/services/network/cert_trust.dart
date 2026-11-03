import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';

class CertTrust extends HttpOverrides {
  static const _prefix = 'tls_sha256:';
  static const _legacyPin = String.fromEnvironment('MONARCH_CERT_SHA256');
  static final _fingerprint = RegExp(r'^[a-f0-9]{64}$');

  static void init() => HttpOverrides.global = CertTrust();

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
