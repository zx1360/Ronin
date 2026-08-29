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
  final int maxChapterNo;

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
    required this.maxChapterNo,
  });

  factory ComixComic.fromJson(Map<String, dynamic> json) {
    return ComixComic(
      comicId: (json['comic_id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      site: json['site'] as String? ?? '',
      siteName: json['site_name'] as String? ?? '',
      detailUrl: json['detail_url'] as String? ?? '',
      relDir: json['rel_dir'] as String? ?? '',
      totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
      downloaded: (json['downloaded'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      maxChapterNo: (json['max_chapter_no'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isLegacy => site == 'legacy';
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

/// 一次爬虫任务（search/add/download/update-check/delete/clean）。
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

  bool get isRunning => status == ComixTaskStatus.running;
}
