/// comix 漫画爬虫管理 —— 领域模型。
///
/// 数据来自 Monarch `/API/comix/*`，JSON 结构遵循 comix 协议文档
/// （docs/协议文档.md）：`{ok, data}` 或 `{ok:false, error, candidates}`。
library;

/// comix 集成配置（只读展示）。
class ComixConfig {
  final String python;
  final String configuredPython;
  final String root;
  final bool available;
  final String message;

  const ComixConfig({
    required this.python,
    required this.configuredPython,
    required this.root,
    required this.available,
    required this.message,
  });

  factory ComixConfig.fromJson(Map<String, dynamic> json) {
    return ComixConfig(
      python: json['python'] as String? ?? '',
      configuredPython: json['configured_python'] as String? ?? '',
      root: json['root'] as String? ?? '',
      available: json['available'] as bool? ?? false,
      message: json['message'] as String? ?? '',
    );
  }
}

/// 站点（site 表）。
class ComixSite {
  final String code;
  final String name;
  final String baseUrl;
  final bool enabled;

  const ComixSite({
    required this.code,
    required this.name,
    required this.baseUrl,
    this.enabled = true,
  });

  factory ComixSite.fromJson(Map<String, dynamic> json) {
    return ComixSite(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      baseUrl: json['base_url'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// 已登记漫画（list 命令输出）。
class ComixComic {
  final int comicId;
  final String title;
  final String site;
  final String siteName;
  final String detailUrl;
  final String relDir;
  final int totalChapters;
  final int downloaded;
  final int failed;
  final int pending;
  final int maxChapterNo;
  final String coverUrl;
  final String coverImage;
  final bool isLegacy;

  const ComixComic({
    required this.comicId,
    required this.title,
    required this.site,
    required this.siteName,
    required this.detailUrl,
    required this.relDir,
    required this.totalChapters,
    required this.downloaded,
    required this.failed,
    required this.pending,
    required this.maxChapterNo,
    this.coverUrl = '',
    this.coverImage = '',
    this.isLegacy = false,
  });

  factory ComixComic.fromJson(Map<String, dynamic> json) {
    final site = json['site'] as String? ?? '';
    final downloaded = (json['downloaded'] as num?)?.toInt() ?? 0;
    final failed = (json['failed'] as num?)?.toInt() ?? 0;
    final total = (json['total_chapters'] as num?)?.toInt() ?? 0;
    return ComixComic(
      comicId: (json['comic_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      site: site,
      siteName: json['site_name'] as String? ?? '',
      detailUrl: json['detail_url'] as String? ?? '',
      relDir: json['rel_dir'] as String? ?? '',
      totalChapters: total,
      downloaded: downloaded,
      failed: failed,
      // pending 优先取后端显式字段；旧后端未返回时按 total-done-failed 回退，
      // 避免把 failed 章节同时算进"待下载"（重复计数的旧逻辑）。
      pending: (json['pending'] as num?)?.toInt() ??
          (total - downloaded - failed).clamp(0, total),
      maxChapterNo: (json['max_chapter_no'] as num?)?.toInt() ?? 0,
      coverUrl: json['cover_url'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      isLegacy: json['is_legacy'] as bool? ?? (site == 'legacy'),
    );
  }

  /// 是否已有可用封面（本地封面路径优先，站点地址兜底）。
  bool get hasCover => coverImage.isNotEmpty || coverUrl.isNotEmpty;

  /// 已下载 + 失败 + 未下载 != 章节总数时为 true，提示统计口径不一致。
  bool get countsConsistent => downloaded + failed + pending == totalChapters;
}

/// 章节状态（chapters 命令输出）。
class ComixChapter {
  final int id;
  final int chapterNo;
  final String title;
  final String status;
  final int pageCount;
  final String relDir;
  final String error;

  const ComixChapter({
    required this.id,
    required this.chapterNo,
    required this.title,
    required this.status,
    required this.pageCount,
    required this.relDir,
    required this.error,
  });

  factory ComixChapter.fromJson(Map<String, dynamic> json) {
    return ComixChapter(
      id: (json['id'] as num?)?.toInt() ?? 0,
      chapterNo: (json['chapter_no'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
      relDir: json['rel_dir'] as String? ?? '',
      error: json['error'] as String? ?? '',
    );
  }
}

/// 任务状态（Go 端任务引擎）。
enum ComixTaskStatus {
  running,
  finished,
  failed,
  killed,
  unknown;

  static ComixTaskStatus parse(String? raw) {
    switch (raw) {
      case 'running':
        return ComixTaskStatus.running;
      case 'finished':
        return ComixTaskStatus.finished;
      case 'failed':
        return ComixTaskStatus.failed;
      case 'killed':
        return ComixTaskStatus.killed;
      default:
        return ComixTaskStatus.unknown;
    }
  }
}

/// 单条任务日志。
class ComixLogEntry {
  final String time;
  final String stream;
  final String text;

  const ComixLogEntry({
    required this.time,
    required this.stream,
    required this.text,
  });

  factory ComixLogEntry.fromJson(Map<String, dynamic> json) {
    return ComixLogEntry(
      time: json['time'] as String? ?? '',
      stream: json['stream'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

/// 一次爬虫任务（download-url/download/update-check/delete/clean/init）。
class ComixTask {
  final String id;
  final String name;
  final String command;
  final ComixTaskStatus status;
  final int pid;
  final String? startedAt;
  final String? finishedAt;
  final int? exitCode;
  final String? error;
  final Map<String, dynamic>? result;
  final List<ComixLogEntry> logs;

  const ComixTask({
    required this.id,
    required this.name,
    required this.command,
    required this.status,
    required this.pid,
    this.startedAt,
    this.finishedAt,
    this.exitCode,
    this.error,
    this.result,
    this.logs = const [],
  });

  factory ComixTask.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    final rawLogs = json['logs'];
    return ComixTask(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      status: ComixTaskStatus.parse(json['status'] as String?),
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      startedAt: json['started_at'] as String?,
      finishedAt: json['finished_at'] as String?,
      exitCode: (json['exit_code'] as num?)?.toInt(),
      error: json['error'] as String?,
      result: rawResult is Map<String, dynamic> ? rawResult : null,
      logs: rawLogs is List
          ? rawLogs
                .whereType<Map<String, dynamic>>()
                .map(ComixLogEntry.fromJson)
                .toList()
          : const [],
    );
  }

  ComixTask copyWith({
    ComixTaskStatus? status,
    String? finishedAt,
    int? exitCode,
    String? error,
    Map<String, dynamic>? result,
    List<ComixLogEntry>? logs,
  }) {
    return ComixTask(
      id: id,
      name: name,
      command: command,
      status: status ?? this.status,
      pid: pid,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      exitCode: exitCode ?? this.exitCode,
      error: error ?? this.error,
      result: result ?? this.result,
      logs: logs ?? this.logs,
    );
  }

  bool get isRunning => status == ComixTaskStatus.running;

  /// 子进程正常退出（含退出码 2 的业务错误）但业务结果为 ok=false。
  bool get isBusinessError =>
      result != null && result!['ok'] == false;

  /// 任务最终是否为"失败"语义：进程级失败或业务级失败都算。
  /// 后端把退出码 2 的 ok=false 记为 finished，直接把 finished 画成绿色"完成"
  /// 会把"漫画不存在/参数错误"这类失败伪装成成功。
  bool get isFailure =>
      status == ComixTaskStatus.failed ||
      status == ComixTaskStatus.killed ||
      isBusinessError ||
      (exitCode != null && exitCode != 0);

  /// 业务错误文本（result.error），无则回退到任务级 error。
  String get failureReason {
    final business = result?['error'];
    if (business is String && business.isNotEmpty) return business;
    if (error != null && error!.isNotEmpty) return error!;
    final stderr = result?['stderr'];
    if (stderr is String && stderr.isNotEmpty) return stderr;
    return '';
  }
}
