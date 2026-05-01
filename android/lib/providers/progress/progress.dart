class Progress {
  final int current;
  final int total;
  final String currentMessage;
  final String message;

  Progress({
    required this.current,
    required this.total,
    required this.currentMessage,
    required this.message,
  });

  Progress.empty({
    this.current=0,
    this.total=0,
    this.currentMessage="",
    this.message="",
  });

  Progress copyWith({
    int? current,
    int? total,
    String? currentMessage,
    String? message,
  }) {
    return Progress(
      current: current ?? this.current,
      total: total ?? this.total,
      currentMessage: currentMessage ?? this.currentMessage,
      message: message ?? this.message,
    );
  }
}
