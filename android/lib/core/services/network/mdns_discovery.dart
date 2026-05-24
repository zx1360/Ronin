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

  /// 扫描局域网内的 Monarch 服务，在 [timeout] 内收集所有发现的服务。
  static Future<List<DiscoveredService>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = MDnsClient();
    await client.start();

    final services = <String, DiscoveredService>{};

    try {
      await for (final ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(_serviceType),
      ).timeout(timeout)) {
        await _resolveService(client, ptr.domainName, services);
      }
    } on TimeoutException {
      // 超时后返回已发现的服务
    } catch (e) {
      // 仅诊断网络不可达错误，其他静默处理
      if (e is SocketException && e.osError?.errorCode == 10049) {
        // 网络不可用
      }
    } finally {
      client.stop();
    }

    return services.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// 解析服务的 SRV / A / TXT 记录
  static Future<void> _resolveService(
    MDnsClient client,
    String domainName,
    Map<String, DiscoveredService> services,
  ) async {
    try {
      // 1. 获取 SRV 记录 (端口 + 目标主机名)
      final srvRecords = await client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(domainName),
          )
          .toList();

      if (srvRecords.isEmpty) return;

      // 2. 获取 TXT 记录 (scheme / auth 等元信息)
      List<TxtResourceRecord> txtRecords;
      try {
        txtRecords = await client
            .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(domainName),
            )
            .toList();
      } catch (_) {
        txtRecords = [];
      }
      final txt = _parseTxtRecords(txtRecords);

      for (final srv in srvRecords) {
        // 3. 从 SRV target 提取主机名 (如 "DESKTOP-XXX.local.")
        final srvTarget = _stripTrailingDot(srv.target);

        // 4. 查询该主机的 A 记录以获取真实 IP
        String host = '';
        try {
          await for (final ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srvTarget),
          ).timeout(const Duration(seconds: 2))) {
            host = ip.address.address;
            break; // 取第一个 IPv4
          }
        } catch (_) {}

        // 5. 回退：尝试用 TXT 中的 ip 字段
        if (host.isEmpty) {
          host = txt['ip'] ?? '';
        }

        // 6. 最后回退：尝试直接解析 srvTarget（若其本身就是 IP 或可解析的域名）
        if (host.isEmpty && _looksLikeIP(srvTarget)) {
          host = srvTarget;
        }

        if (host.isEmpty) continue;

        final scheme = txt['scheme'] == 'http' ? 'http' : 'https';
        final hasAuth = txt['auth'] == 'yes';

        final key = '$host:${srv.port}';
        if (!services.containsKey(key)) {
          services[key] = DiscoveredService(
            name: domainName,
            host: host,
            port: srv.port,
            scheme: scheme,
            hasAuth: hasAuth,
            txtRecords: txt,
          );
        }
      }
    } catch (_) {
      // 解析失败则跳过该服务
    }
  }

  /// 解析 mDNS TXT 记录为 Map
  ///
  /// DNS-SD 标准: 每个 key=value 对是 TXT RDATA 中的独立 character-string。
  /// Dart multicast_dns 包的 TxtResourceRecord.text 会将它们拼接在一起。
  /// 我们同时尝试 ';' 分隔和无分隔两种模式。
  static Map<String, String> _parseTxtRecords(List<TxtResourceRecord> records) {
    final result = <String, String>{};
    for (final record in records) {
      final raw = record.text;
      // 尝试 ';' 分隔
      final entries = raw.contains(';') ? raw.split(';') : <String>[raw];
      for (final entry in entries) {
        final eq = entry.indexOf('=');
        if (eq > 0) {
          final key = entry.substring(0, eq).trim();
          final value = entry.substring(eq + 1).trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            result[key] = value;
          }
        }
      }
    }
    return result;
  }

  static String _stripTrailingDot(String s) {
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  static bool _looksLikeIP(String s) {
    return RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(s);
  }
}
