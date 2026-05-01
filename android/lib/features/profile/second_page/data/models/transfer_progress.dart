/// 数据传输进度模型
///
/// 用于跟踪同步/备份操作的进度状态。
library;

/// 传输操作类型
enum TransferType {
  sync, // 同步到本地
  backup, // 备份到PC
}

/// 传输目标类型
enum TransferTarget {
  all, // 所有数据
  booklet, // 打卡数据
  essay, // 随笔数据
}

/// 传输状态
enum TransferStatus {
  idle, // 空闲
  preparing, // 准备中
  inProgress, // 传输中
  retrying, // 重试中
  success, // 成功
  failed, // 失败
}

/// 传输进度
class TransferProgress {
  final TransferType type;
  final TransferTarget target;
  final TransferStatus status;
  final int total;
  final int current;
  final String currentMessage;
  final String message;
  final List<FailedItem> failedItems;
  final String? errorMessage;
  final DateTime? startTime;
  final DateTime? endTime;

  const TransferProgress({
    required this.type,
    required this.target,
    this.status = TransferStatus.idle,
    this.total = 0,
    this.current = 0,
    this.currentMessage = '',
    this.message = '',
    this.failedItems = const [],
    this.errorMessage,
    this.startTime,
    this.endTime,
  });

  factory TransferProgress.idle() => const TransferProgress(
    type: TransferType.sync,
    target: TransferTarget.booklet,
    status: TransferStatus.idle,
  );

  bool get isIdle => status == TransferStatus.idle;
  bool get isInProgress =>
      status == TransferStatus.inProgress ||
      status == TransferStatus.preparing ||
      status == TransferStatus.retrying;
  bool get isCompleted =>
      status == TransferStatus.success || status == TransferStatus.failed;
  bool get isSuccess => status == TransferStatus.success;
  bool get hasFailedItems => failedItems.isNotEmpty;
  double get progress => total > 0 ? current / total : 0.0;
  int get progressPercent => (progress * 100).round();

  Duration? get elapsed {
    if (startTime == null) return null;
    return (endTime ?? DateTime.now()).difference(startTime!);
  }

  String get typeName => type == TransferType.sync ? '同步' : '备份';
  String get targetName => target == TransferTarget.booklet ? '打卡' : '随笔';
  String get statusName => switch (status) {
    TransferStatus.idle => '就绪',
    TransferStatus.preparing => '准备中',
    TransferStatus.inProgress => '传输中',
    TransferStatus.retrying => '重试中',
    TransferStatus.success => '完成',
    TransferStatus.failed => '失败',
  };

  TransferProgress copyWith({
    TransferType? type,
    TransferTarget? target,
    TransferStatus? status,
    int? total,
    int? current,
    String? currentMessage,
    String? message,
    List<FailedItem>? failedItems,
    String? errorMessage,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return TransferProgress(
      type: type ?? this.type,
      target: target ?? this.target,
      status: status ?? this.status,
      total: total ?? this.total,
      current: current ?? this.current,
      currentMessage: currentMessage ?? this.currentMessage,
      message: message ?? this.message,
      failedItems: failedItems ?? this.failedItems,
      errorMessage: errorMessage ?? this.errorMessage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

/// 传输失败的项目
class FailedItem {
  final String name;
  final String path;
  final String error;
  final int retryCount;

  const FailedItem({
    required this.name,
    required this.path,
    required this.error,
    this.retryCount = 0,
  });

  FailedItem copyWith({
    String? name,
    String? path,
    String? error,
    int? retryCount,
  }) {
    return FailedItem(
      name: name ?? this.name,
      path: path ?? this.path,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// 传输结果
class TransferResult {
  final bool success;
  final String message;
  final int successCount;
  final int failedCount;
  final List<FailedItem> failedItems;
  final Duration? elapsed;

  const TransferResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failedCount = 0,
    this.failedItems = const [],
    this.elapsed,
  });

  factory TransferResult.success({
    required String message,
    int successCount = 0,
    Duration? elapsed,
  }) => TransferResult(
    success: true,
    message: message,
    successCount: successCount,
    elapsed: elapsed,
  );

  factory TransferResult.failed({
    required String message,
    int successCount = 0,
    int failedCount = 0,
    List<FailedItem> failedItems = const [],
    Duration? elapsed,
  }) => TransferResult(
    success: false,
    message: message,
    successCount: successCount,
    failedCount: failedCount,
    failedItems: failedItems,
    elapsed: elapsed,
  );
}

/// 传输操作配置
class TransferAction {
  final TransferType type;
  final TransferTarget target;
  final String label;
  final bool highlighted;

  const TransferAction({
    required this.type,
    required this.target,
    required this.label,
    this.highlighted = false,
  });
}
