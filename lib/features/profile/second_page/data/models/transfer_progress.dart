/// 数据传输进度模型
/// 
/// 用于跟踪同步/备份操作的进度状态。
library;

/// 传输操作类型
enum TransferType {
  sync,   // 同步到本地
  backup, // 备份到PC
}

/// 传输目标类型
enum TransferTarget {
  booklet, // 打卡数据
  essay,   // 随笔数据
  all,     // 全部数据
}

/// 传输状态
enum TransferStatus {
  idle,       // 空闲
  preparing,  // 准备中
  inProgress, // 传输中
  retrying,   // 重试中
  success,    // 成功
  failed,     // 失败
  cancelled,  // 已取消
}

/// 传输进度
class TransferProgress {
  /// 传输操作类型
  final TransferType type;
  
  /// 传输目标类型
  final TransferTarget target;
  
  /// 当前状态
  final TransferStatus status;
  
  /// 总数量（文件/图片数量）
  final int total;
  
  /// 当前完成数量
  final int current;
  
  /// 当前操作描述
  final String currentMessage;
  
  /// 主要状态描述
  final String message;
  
  /// 失败的项目列表
  final List<FailedItem> failedItems;
  
  /// 错误信息
  final String? errorMessage;
  
  /// 开始时间
  final DateTime? startTime;
  
  /// 结束时间
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

  /// 创建空进度对象
  factory TransferProgress.empty() => const TransferProgress(
    type: TransferType.sync,
    target: TransferTarget.all,
  );

  /// 是否正在进行中
  bool get isInProgress => status == TransferStatus.inProgress || 
                            status == TransferStatus.preparing ||
                            status == TransferStatus.retrying;

  /// 是否已完成（成功或失败）
  bool get isCompleted => status == TransferStatus.success || 
                          status == TransferStatus.failed;

  /// 是否成功
  bool get isSuccess => status == TransferStatus.success;

  /// 是否有失败项
  bool get hasFailedItems => failedItems.isNotEmpty;

  /// 计算进度百分比 (0.0 - 1.0)
  double get progress => total > 0 ? current / total : 0.0;

  /// 计算进度百分比 (0 - 100)
  int get progressPercent => (progress * 100).round();

  /// 计算耗时
  Duration? get elapsed {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  /// 格式化操作类型名称
  String get typeName => switch (type) {
    TransferType.sync => '同步',
    TransferType.backup => '备份',
  };

  /// 格式化目标类型名称
  String get targetName => switch (target) {
    TransferTarget.booklet => '打卡',
    TransferTarget.essay => '随笔',
    TransferTarget.all => '全部',
  };

  /// 格式化状态名称
  String get statusName => switch (status) {
    TransferStatus.idle => '就绪',
    TransferStatus.preparing => '准备中',
    TransferStatus.inProgress => '传输中',
    TransferStatus.retrying => '重试中',
    TransferStatus.success => '完成',
    TransferStatus.failed => '失败',
    TransferStatus.cancelled => '已取消',
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
