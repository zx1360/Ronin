class OpsOverview {
  final OpsServiceOverview service;
  final OpsDatabaseOverview database;
  final Map<String, OpsStorageOverview> storage;

  // 预留扩展点，未来可接入 /api/ops/drives。
  final Map<String, OpsDriveOverview> drives;

  const OpsOverview({
    required this.service,
    required this.database,
    required this.storage,
    required this.drives,
  });

  factory OpsOverview.fromJson(Map<String, dynamic> json) {
    final serviceRaw = (json['service'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final databaseRaw = (json['database'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final storageRaw = (json['storage'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final drivesRaw =
        (json['drives'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final storage = <String, OpsStorageOverview>{};
    for (final entry in storageRaw.entries) {
      final value = (entry.value as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      storage[entry.key] = OpsStorageOverview.fromJson(value);
    }

    final drives = <String, OpsDriveOverview>{};
    for (final entry in drivesRaw.entries) {
      final value = (entry.value as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      drives[entry.key] = OpsDriveOverview.fromJson(value);
    }

    return OpsOverview(
      service: OpsServiceOverview.fromJson(serviceRaw),
      database: OpsDatabaseOverview.fromJson(databaseRaw),
      storage: storage,
      drives: drives,
    );
  }
}

class OpsServiceOverview {
  final bool isLocalMode;
  final int? port;

  const OpsServiceOverview({
    required this.isLocalMode,
    required this.port,
  });

  factory OpsServiceOverview.fromJson(Map<String, dynamic> json) {
    return OpsServiceOverview(
      isLocalMode: json['isLocalMode'] == true,
      port: int.tryParse((json['port'] ?? '').toString()),
    );
  }
}

class OpsDatabaseOverview {
  final bool reachable;
  final String? error;

  const OpsDatabaseOverview({
    required this.reachable,
    required this.error,
  });

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

class OpsDriveOverview {
  final int? totalBytes;
  final int? usedBytes;

  const OpsDriveOverview({
    required this.totalBytes,
    required this.usedBytes,
  });

  factory OpsDriveOverview.fromJson(Map<String, dynamic> json) {
    return OpsDriveOverview(
      totalBytes: int.tryParse((json['totalBytes'] ?? '').toString()),
      usedBytes: int.tryParse((json['usedBytes'] ?? '').toString()),
    );
  }
}
