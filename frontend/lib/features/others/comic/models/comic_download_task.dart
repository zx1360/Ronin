enum ComicDownloadTaskStatus {
  queued,
  running,
  paused,
  retryWaiting,
  completed,
  failed,
  canceled,
}

class ComicDownloadTask {
  final String taskId;
  final String comicId;
  final String comicName;
  final String coverImage;
  final ComicDownloadTaskStatus status;
  final int totalChapters;
  final int completedChapters;
  final int totalImages;
  final int downloadedImages;
  final String currentChapterName;
  final String? errorMessage;
  final int retryCount;
  final int createdAtMs;
  final int updatedAtMs;
  final int? nextRetryAtMs;

  const ComicDownloadTask({
    required this.taskId,
    required this.comicId,
    required this.comicName,
    required this.coverImage,
    required this.status,
    required this.totalChapters,
    required this.completedChapters,
    required this.totalImages,
    required this.downloadedImages,
    required this.currentChapterName,
    required this.errorMessage,
    required this.retryCount,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.nextRetryAtMs,
  });

  factory ComicDownloadTask.newTask({
    required String taskId,
    required String comicId,
    required String comicName,
    required String coverImage,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ComicDownloadTask(
      taskId: taskId,
      comicId: comicId,
      comicName: comicName,
      coverImage: coverImage,
      status: ComicDownloadTaskStatus.queued,
      totalChapters: 0,
      completedChapters: 0,
      totalImages: 0,
      downloadedImages: 0,
      currentChapterName: '',
      errorMessage: null,
      retryCount: 0,
      createdAtMs: now,
      updatedAtMs: now,
      nextRetryAtMs: null,
    );
  }

  bool get isTerminal {
    return status == ComicDownloadTaskStatus.completed ||
        status == ComicDownloadTaskStatus.failed ||
        status == ComicDownloadTaskStatus.canceled;
  }

  bool get hasActiveWork {
    return status == ComicDownloadTaskStatus.queued ||
        status == ComicDownloadTaskStatus.running ||
        status == ComicDownloadTaskStatus.paused ||
        status == ComicDownloadTaskStatus.retryWaiting;
  }

  bool get canResume {
    return status == ComicDownloadTaskStatus.paused ||
        status == ComicDownloadTaskStatus.failed ||
        status == ComicDownloadTaskStatus.retryWaiting;
  }

  double get progress {
    if (totalImages <= 0) return 0;
    return downloadedImages / totalImages;
  }

  ComicDownloadTask copyWith({
    String? taskId,
    String? comicId,
    String? comicName,
    String? coverImage,
    ComicDownloadTaskStatus? status,
    int? totalChapters,
    int? completedChapters,
    int? totalImages,
    int? downloadedImages,
    String? currentChapterName,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? retryCount,
    int? createdAtMs,
    int? updatedAtMs,
    int? nextRetryAtMs,
    bool clearNextRetryAtMs = false,
  }) {
    return ComicDownloadTask(
      taskId: taskId ?? this.taskId,
      comicId: comicId ?? this.comicId,
      comicName: comicName ?? this.comicName,
      coverImage: coverImage ?? this.coverImage,
      status: status ?? this.status,
      totalChapters: totalChapters ?? this.totalChapters,
      completedChapters: completedChapters ?? this.completedChapters,
      totalImages: totalImages ?? this.totalImages,
      downloadedImages: downloadedImages ?? this.downloadedImages,
      currentChapterName: currentChapterName ?? this.currentChapterName,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      retryCount: retryCount ?? this.retryCount,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      nextRetryAtMs: clearNextRetryAtMs
          ? null
          : (nextRetryAtMs ?? this.nextRetryAtMs),
    );
  }

  static ComicDownloadTaskStatus statusFromName(String value) {
    switch (value) {
      case 'queued':
        return ComicDownloadTaskStatus.queued;
      case 'running':
        return ComicDownloadTaskStatus.running;
      case 'paused':
        return ComicDownloadTaskStatus.paused;
      case 'retryWaiting':
        return ComicDownloadTaskStatus.retryWaiting;
      case 'completed':
        return ComicDownloadTaskStatus.completed;
      case 'failed':
        return ComicDownloadTaskStatus.failed;
      case 'canceled':
        return ComicDownloadTaskStatus.canceled;
      default:
        return ComicDownloadTaskStatus.queued;
    }
  }

  factory ComicDownloadTask.fromJson(Map<String, dynamic> json) {
    return ComicDownloadTask(
      taskId: json['task_id'] as String? ?? '',
      comicId: json['comic_id'] as String? ?? '',
      comicName: json['comic_name'] as String? ?? '',
      coverImage: json['cover_image'] as String? ?? '',
      status: statusFromName(json['status'] as String? ?? 'queued'),
      totalChapters: json['total_chapters'] as int? ?? 0,
      completedChapters: json['completed_chapters'] as int? ?? 0,
      totalImages: json['total_images'] as int? ?? 0,
      downloadedImages: json['downloaded_images'] as int? ?? 0,
      currentChapterName: json['current_chapter_name'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
      retryCount: json['retry_count'] as int? ?? 0,
      createdAtMs: json['created_at_ms'] as int? ?? 0,
      updatedAtMs: json['updated_at_ms'] as int? ?? 0,
      nextRetryAtMs: json['next_retry_at_ms'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'comic_id': comicId,
      'comic_name': comicName,
      'cover_image': coverImage,
      'status': status.name,
      'total_chapters': totalChapters,
      'completed_chapters': completedChapters,
      'total_images': totalImages,
      'downloaded_images': downloadedImages,
      'current_chapter_name': currentChapterName,
      'error_message': errorMessage,
      'retry_count': retryCount,
      'created_at_ms': createdAtMs,
      'updated_at_ms': updatedAtMs,
      'next_retry_at_ms': nextRetryAtMs,
    };
  }
}

extension ComicDownloadTaskStatusX on ComicDownloadTaskStatus {
  String get label {
    switch (this) {
      case ComicDownloadTaskStatus.queued:
        return '排队中';
      case ComicDownloadTaskStatus.running:
        return '下载中';
      case ComicDownloadTaskStatus.paused:
        return '已暂停';
      case ComicDownloadTaskStatus.retryWaiting:
        return '等待重试';
      case ComicDownloadTaskStatus.completed:
        return '已完成';
      case ComicDownloadTaskStatus.failed:
        return '失败';
      case ComicDownloadTaskStatus.canceled:
        return '已取消';
    }
  }
}
