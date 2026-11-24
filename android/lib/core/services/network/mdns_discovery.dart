import 'dart:async';
import 'dart:io';

import 'package:multicast_dns/multicast_dns.dart';

/// mDNS 服务发现结果
class DiscoveredService {
  final String name;
  final String host;
  final int port;
  final String scheme; // "http" 或 "https"
  final bool hasAuth;
  final Map<String, String> txtRecords;

  const DiscoveredService({
    required this.name,
    required this.host,
    required this.port,
    required this.scheme,
    required this.hasAuth,
    required this.txtRecords,
  });

  /// 构建 API Base URL
  String get baseUrl => '$scheme://$host:$port';

  @override
  String toString() => 'DiscoveredService($name, $baseUrl)';
}

/// mDNS 服务发现客户端
///
/// 通过组播 DNS 自动发现局域网内的 Monarch 服务。
class MDnsDiscovery {
  MDnsDiscovery._();

  static const String _serviceType = '_monarch._tcp';

  /// 扫描局域网内的 Monarch 服务
  ///
  /// 收到首个响应后若 [quietPeriod] 内没有新服务即提前返回, 因此正常情况下
  /// 几百毫秒即可完成; [timeout] 是"什么都没发现"时的等待上限.
  static Future<List<DiscoveredService>> discover({
    Duration timeout = const Duration(seconds: 2),
    Duration quietPeriod = const Duration(milliseconds: 350),
  }) async {
    final client = MDnsClient();
    final services = <String, DiscoveredService>{};

    try {
      await client.start();
      await _collect(client, services, timeout, quietPeriod);
    } catch (_) {
      // 网络不可用或查询异常: 返回已收集到的部分结果
    } finally {
      client.stop();
    }

    return services.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 收集 PTR 响应并解析, 直到静默期或总超时结束
  static Future<void> _collect(
    MDnsClient client,
    Map<String, DiscoveredService> services,
    Duration timeout,
    Duration quietPeriod,
  ) async {
    final pending = <String, Future<void>>{};
    final elapsed = Stopwatch()..start();
    Duration remaining() => timeout - elapsed.elapsed;
    final done = Completer<void>();
    Timer? quietTimer;

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    final overallTimer = Timer(timeout, finish);
    final subscription = client
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(_serviceType),
          timeout: timeout,
        )
        .listen((ptr) {
          if (pending.containsKey(ptr.domainName)) return;
          pending[ptr.domainName] = _resolveService(
            client,
            ptr.domainName,
            services,
            remaining,
          );
          quietTimer?.cancel();
          quietTimer = Timer(quietPeriod, finish);
        }, onError: (_) {});

    try {
      await done.future;
    } finally {
      overallTimer.cancel();
      quietTimer?.cancel();
      await subscription.cancel();
    }

    await Future.wait(pending.values);
  }

  static Future<void> _resolveService(
    MDnsClient client,
    String domainName,
    Map<String, DiscoveredService> services,
    Duration Function() remaining,
  ) async {
    Future<T?> resolve<T extends ResourceRecord>(
      ResourceRecordQuery query,
    ) async {
      try {
        final time = remaining();
        if (time <= Duration.zero) return null;
        return await client.lookup<T>(query, timeout: time).first;
      } catch (_) {
        return null;
      }
    }

    final txtResult = resolve<TxtResourceRecord>(
      ResourceRecordQuery.text(domainName),
    );
    final srv = await resolve<SrvResourceRecord>(
      ResourceRecordQuery.service(domainName),
    );
    if (srv == null) return;
    final target = srv.target.replaceFirst(RegExp(r'\.$'), '');
    final directAddress = _ipv4(target);
    final address = directAddress == null
        ? await resolve<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(target),
          )
        : null;
    final txt = _parseTxtRecords((await txtResult)?.text ?? '');
    final host = address?.address.address ?? _ipv4(txt['ip']) ?? directAddress;
    if (host == null) return;
    services.putIfAbsent(
      '$host:${srv.port}',
      () => DiscoveredService(
        name: domainName,
        host: host,
        port: srv.port,
        scheme: txt['scheme'] == 'http' ? 'http' : 'https',
        hasAuth: txt['auth'] == 'yes',
        txtRecords: txt,
      ),
    );
  }

  static Map<String, String> _parseTxtRecords(String text) {
    final result = <String, String>{};
    for (final entry in text.split(RegExp(r'[;\r\n]+'))) {
      final eq = entry.indexOf('=');
      if (eq > 0) {
        final key = entry.substring(0, eq).trim();
        final value = entry.substring(eq + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
      }
    }
    return result;
  }

  static String? _ipv4(String? value) {
    final address = value == null ? null : InternetAddress.tryParse(value);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return null;
    }
    return address.address;
  }
}
