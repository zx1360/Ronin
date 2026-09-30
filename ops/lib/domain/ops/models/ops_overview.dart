class OpsOverview {
  final OpsServiceOverview service;
  final OpsDatabaseOverview database;
  final Map<String, OpsStorageOverview> storage;

  const OpsOverview({
    required this.service,
    required this.database,
    required this.storage,
  });

  factory OpsOverview.fromJson(Map<String, dynamic> json) {
    final serviceRaw =
        (json['service'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final databaseRaw =
        (json['database'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final storageRaw =
        (json['storage'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final storage = <String, OpsStorageOverview>{};
    for (final entry in storageRaw.entries) {
      final value =
          (entry.value as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      storage[entry.key] = OpsStorageOverview.fromJson(value);
    }

    return OpsOverview(
      service: OpsServiceOverview.fromJson(serviceRaw),
      database: OpsDatabaseOverview.fromJson(databaseRaw),
      storage: storage,
    );
  }
}

class OpsServiceOverview {
  final bool isLocalMode;
  final int? port;

  /// static 目录的绝对路径（服务端视角）：桌面端替换封面需要直接读写该目录，
  /// 相对路径在客户端无法解析（两端工作目录不同）。
  final String staticDir;

  const OpsServiceOverview({
    required this.isLocalMode,
    required this.port,
    this.staticDir = '',
  });

  factory OpsServiceOverview.fromJson(Map<String, dynamic> json) {
    return OpsServiceOverview(
      isLocalMode: json['isLocalMode'] == true,
      port: int.tryParse((json['port'] ?? '').toString()),
      staticDir: (json['staticDir'] ?? '').toString(),
    );
  }
}

class OpsDatabaseOverview {
  final bool reachable;
  final String? error;

  const OpsDatabaseOverview({required this.reachable, required this.error});

  factory OpsDatabaseOverview.fromJson(Map<String, dynamic> json) {
    final rawError = (json['error'] ?? '').toString().trim();
    return OpsDatabaseOverview(
      reachable: json['reachable'] == true,
      error: rawError.isEmpty ? null : rawError,
    );
  }
}

class OpsStorageOverview {
  final String path;
  final bool exists;
  final int files;
  final int bytes;
  final String? error;

  const OpsStorageOverview({
    required this.path,
    required this.exists,
    required this.files,
    required this.bytes,
    required this.error,
  });

  factory OpsStorageOverview.fromJson(Map<String, dynamic> json) {
    final rawError = (json['error'] ?? '').toString().trim();

    return OpsStorageOverview(
      path: (json['path'] ?? '').toString(),
      exists: json['exists'] == true,
      files: int.tryParse((json['files'] ?? '0').toString()) ?? 0,
      bytes: int.tryParse((json['bytes'] ?? '0').toString()) ?? 0,
      error: rawError.isEmpty ? null : rawError,
    );
  }
}
