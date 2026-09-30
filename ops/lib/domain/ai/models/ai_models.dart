/// AI 媒体处理层的数据模型。
///
/// 与后端 `/API/ai/*` 的 JSON 一一对应；字段名保持后端原样（snake_case），
/// 便于对照 `backend/references/api/routes.json` 排查。
library;

/// 数值取值辅助：JSON 里数字可能是 int 也可能是 double。
int _int(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _double(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return fallback;
}

String _string(dynamic value, [String fallback = '']) {
  return value is String ? value : fallback;
}

bool _bool(dynamic value, [bool fallback = false]) {
  return value is bool ? value : fallback;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value.map((e) => e.toString()).toList();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

/// 侧车（Python AI 进程）运行状态。
class AiSidecarState {
  final String capability;
  final bool running;
  final int pid;
  final int idleSeconds;
  final int idleTimeoutSeconds;
  final String python;
  final bool probeOk;
  final String? probeError;
  final List<String> missingModels;

  const AiSidecarState({
    required this.capability,
    required this.running,
    required this.pid,
    required this.idleSeconds,
    required this.idleTimeoutSeconds,
    required this.python,
    required this.probeOk,
    this.probeError,
    this.missingModels = const [],
  });

  factory AiSidecarState.fromJson(Map<String, dynamic> json) {
    return AiSidecarState(
      capability: _string(json['capability']),
      running: _bool(json['running']),
      pid: _int(json['pid']),
      idleSeconds: _int(json['idle_seconds']),
      idleTimeoutSeconds: _int(json['idle_timeout_seconds']),
      python: _string(json['python']),
      probeOk: _bool(json['probe_ok']),
      probeError: json['probe_error'] as String?,
      missingModels: _stringList(json['missing_models']),
    );
  }
}

/// 单个 AI 能力的就绪与队列状态。
class AiCapabilityStatus {
  final String capability;
  final bool ready;
  final String? reason;
  final AiSidecarState? sidecar;
  final int missingMedia;
  final int pending;
  final int failed;
  final int done;

  const AiCapabilityStatus({
    required this.capability,
    required this.ready,
    this.reason,
    this.sidecar,
    required this.missingMedia,
    required this.pending,
    required this.failed,
    required this.done,
  });

  factory AiCapabilityStatus.fromJson(Map<String, dynamic> json) {
    final sidecar = json['sidecar'];
    return AiCapabilityStatus(
      capability: _string(json['capability']),
      ready: _bool(json['ready']),
      reason: json['reason'] as String?,
      sidecar: sidecar == null ? null : AiSidecarState.fromJson(_map(sidecar)),
      missingMedia: _int(json['missing_media']),
      pending: _int(json['pending']),
      failed: _int(json['failed']),
      done: _int(json['done']),
    );
  }

  /// 该能力是否已处理完所有媒体（无待处理且无待补）。
  bool get settled => pending == 0 && missingMedia == 0;
}

/// 队列计数。
class AiQueueStat {
  final String capability;
  final int pending;
  final int running;
  final int done;
  final int failed;
  final int total;

  const AiQueueStat({
    required this.capability,
    required this.pending,
    required this.running,
    required this.done,
    required this.failed,
    required this.total,
  });

  factory AiQueueStat.fromJson(Map<String, dynamic> json) {
    return AiQueueStat(
      capability: _string(json['capability']),
      pending: _int(json['pending']),
      running: _int(json['running']),
      done: _int(json['done']),
      failed: _int(json['failed']),
      total: _int(json['total']),
    );
  }
}

/// 当前/最近一次批次执行信息。
class AiRunInfo {
  final String capability;
  final int total;
  final int processed;
  final int failed;
  final bool running;

  const AiRunInfo({
    required this.capability,
    required this.total,
    required this.processed,
    required this.failed,
    required this.running,
  });

  factory AiRunInfo.fromJson(Map<String, dynamic> json) {
    return AiRunInfo(
      capability: _string(json['capability']),
      total: _int(json['total']),
      processed: _int(json['processed']),
      failed: _int(json['failed']),
      running: _bool(json['running']),
    );
  }
}

/// 内存向量索引状态。
class AiIndexState {
  final String model;
  final int vectors;
  final bool loaded;
  final int memoryEstimateBytes;

  const AiIndexState({
    required this.model,
    required this.vectors,
    required this.loaded,
    required this.memoryEstimateBytes,
  });

  factory AiIndexState.fromJson(Map<String, dynamic> json) {
    return AiIndexState(
      model: _string(json['model']),
      vectors: _int(json['vectors']),
      loaded: _bool(json['loaded']),
      memoryEstimateBytes: _int(json['memory_estimate_bytes']),
    );
  }
}

/// Ollama 服务状态。
class AiOllamaState {
  final String url;

  /// 当前生效的 VLM 标注模型（标准版或备选的无审查版）。
  final String model;

  /// 两个候选：标准版 / 无审查版。
  final String modelDefault;
  final String modelAlt;

  /// 当前正在推理的模型（空 = 空闲）。
  final String activeModel;

  /// 最近一次后台标注被前台对话抢占的说明（空 = 无）。
  final String lastSwitch;
  final int numCtx;
  final bool reachable;
  final bool modelReady;
  final String? error;
  final bool ownedServer;
  final int pid;
  final int idleSeconds;
  final List<String> models;

  const AiOllamaState({
    required this.url,
    required this.model,
    required this.modelDefault,
    required this.modelAlt,
    required this.activeModel,
    this.lastSwitch = '',
    required this.numCtx,
    required this.reachable,
    required this.modelReady,
    this.error,
    required this.ownedServer,
    required this.pid,
    required this.idleSeconds,
    this.models = const [],
  });

  factory AiOllamaState.fromJson(Map<String, dynamic> json) {
    return AiOllamaState(
      url: _string(json['url']),
      model: _string(json['model']),
      modelDefault: _string(json['model_default']),
      modelAlt: _string(json['model_alt']),
      activeModel: _string(json['active_model']),
      lastSwitch: _string(json['last_switch']),
      numCtx: _int(json['num_ctx']),
      reachable: _bool(json['reachable']),
      modelReady: _bool(json['model_ready']),
      error: json['error'] as String?,
      ownedServer: _bool(json['owned_server']),
      pid: _int(json['pid']),
      idleSeconds: _int(json['idle_seconds']),
      models: _stringList(json['models']),
    );
  }

  /// 模型是否已安装（容忍 tag 差异）。
  bool isInstalled(String model) {
    for (final item in models) {
      if (item == model || item.startsWith('$model:')) return true;
    }
    return false;
  }
}

/// 人脸聚类状态。
class AiClusterState {
  final int persons;
  final double threshold;
  final int minGroupFaces;
  final bool centroidsLoaded;

  const AiClusterState({
    required this.persons,
    required this.threshold,
    required this.minGroupFaces,
    required this.centroidsLoaded,
  });

  factory AiClusterState.fromJson(Map<String, dynamic> json) {
    return AiClusterState(
      persons: _int(json['persons']),
      threshold: _double(json['threshold']),
      minGroupFaces: _int(json['min_group_faces']),
      centroidsLoaded: _bool(json['centroids_loaded']),
    );
  }
}

/// AI 处理层整体状态。
class AiStatus {
  final bool enabled;
  final bool schemaReady;
  final bool started;
  final String embedModel;
  final String device;
  final int workers;
  final int batchSize;
  final int idleTimeoutSeconds;
  final int jobTimeoutSeconds;
  final int maxAttempts;
  final bool paused;
  final List<String> autoCapabilities;
  final List<AiCapabilityStatus> capabilities;
  final List<AiQueueStat> queue;
  final int pendingTotal;
  final int failedTotal;
  final AiRunInfo? lastRun;
  final AiIndexState index;
  final AiClusterState cluster;
  final AiOllamaState ollama;
  final int personCount;

  const AiStatus({
    required this.enabled,
    required this.schemaReady,
    required this.started,
    required this.embedModel,
    required this.device,
    required this.workers,
    required this.batchSize,
    required this.idleTimeoutSeconds,
    required this.jobTimeoutSeconds,
    required this.maxAttempts,
    this.paused = false,
    this.autoCapabilities = const [],
    this.capabilities = const [],
    this.queue = const [],
    required this.pendingTotal,
    required this.failedTotal,
    this.lastRun,
    required this.index,
    required this.cluster,
    required this.ollama,
    required this.personCount,
  });

  factory AiStatus.fromJson(Map<String, dynamic> json) {
    return AiStatus(
      enabled: _bool(json['enabled']),
      schemaReady: _bool(json['schema_ready']),
      started: _bool(json['started']),
      embedModel: _string(json['embed_model']),
      device: _string(json['device']),
      workers: _int(json['workers']),
      batchSize: _int(json['batch_size']),
      idleTimeoutSeconds: _int(json['idle_timeout_seconds']),
      jobTimeoutSeconds: _int(json['job_timeout_seconds']),
      maxAttempts: _int(json['max_attempts']),
      paused: _bool(json['paused']),
      autoCapabilities: _stringList(json['auto_capabilities']),
      capabilities: (json['capabilities'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AiCapabilityStatus.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      queue: (json['queue'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AiQueueStat.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pendingTotal: _int(json['pending_total']),
      failedTotal: _int(json['failed_total']),
      lastRun: json['last_run'] == null
          ? null
          : AiRunInfo.fromJson(_map(json['last_run'])),
      index: AiIndexState.fromJson(_map(json['index'])),
      cluster: AiClusterState.fromJson(_map(json['cluster'])),
      ollama: AiOllamaState.fromJson(_map(json['ollama'])),
      personCount: _int(json['person_count']),
    );
  }

  AiCapabilityStatus? capabilityOf(String name) {
    for (final item in capabilities) {
      if (item.capability == name) return item;
    }
    return null;
  }
}

/// 一条 AI 处理任务。
class AiJob {
  final int id;
  final String capability;
  final String mediaId;
  final String status;
  final int attempts;
  final String? lastError;

  const AiJob({
    required this.id,
    required this.capability,
    required this.mediaId,
    required this.status,
    required this.attempts,
    this.lastError,
  });

  factory AiJob.fromJson(Map<String, dynamic> json) {
    return AiJob(
      id: _int(json['id']),
      capability: _string(json['capability']),
      mediaId: _string(json['media_id']),
      status: _string(json['status']),
      attempts: _int(json['attempts']),
      lastError: json['last_error'] as String?,
    );
  }
}

/// 人物分组。
class AiPerson {
  final String id;
  final String? name;
  final String? coverMediaId;
  final int faceCount;

  const AiPerson({
    required this.id,
    this.name,
    this.coverMediaId,
    required this.faceCount,
  });

  factory AiPerson.fromJson(Map<String, dynamic> json) {
    return AiPerson(
      id: _string(json['id']),
      name: json['name'] as String?,
      coverMediaId: json['cover_media_id'] as String?,
      faceCount: _int(json['face_count']),
    );
  }

  String get displayName => (name == null || name!.isEmpty) ? '未命名' : name!;
}

/// pHash 近重复分组。
class AiDuplicateGroup {
  final int distance;
  final List<String> mediaIds;
  final List<String> files;

  const AiDuplicateGroup({
    required this.distance,
    required this.mediaIds,
    required this.files,
  });

  factory AiDuplicateGroup.fromJson(Map<String, dynamic> json) {
    return AiDuplicateGroup(
      distance: _int(json['distance']),
      mediaIds: _stringList(json['media_ids']),
      files: _stringList(json['files']),
    );
  }
}

/// 搜索命中的媒体（媒体字段 + 相关度）。
class AiSearchHit {
  final String id;
  final String filePath;
  final String? thumbPath;
  final String? previewPath;
  final String? mimeType;
  final String? capturedAt;
  final int sizeBytes;
  final double score;
  final List<String> source;

  const AiSearchHit({
    required this.id,
    required this.filePath,
    this.thumbPath,
    this.previewPath,
    this.mimeType,
    this.capturedAt,
    required this.sizeBytes,
    required this.score,
    this.source = const [],
  });

  factory AiSearchHit.fromJson(Map<String, dynamic> json) {
    return AiSearchHit(
      id: _string(json['id']),
      filePath: _string(json['file_path']),
      thumbPath: json['thumb_path'] as String?,
      previewPath: json['preview_path'] as String?,
      mimeType: json['mime_type'] as String?,
      capturedAt: json['captured_at'] as String?,
      sizeBytes: _int(json['size_bytes']),
      score: _double(json['score']),
      source: _stringList(json['source']),
    );
  }

  bool get isVideo => (mimeType ?? '').startsWith('video/');
}

/// 搜索结果集。
class AiSearchResult {
  final List<AiSearchHit> hits;
  final int total;
  final String mode;

  const AiSearchResult({
    required this.hits,
    required this.total,
    required this.mode,
  });

  static const empty = AiSearchResult(hits: [], total: 0, mode: '');

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    return AiSearchResult(
      hits: (json['hits'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AiSearchHit.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _int(json['total']),
      mode: _string(json['mode']),
    );
  }
}
