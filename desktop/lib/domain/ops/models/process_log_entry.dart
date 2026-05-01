enum LogStreamType {
  stdout,
  stderr,
  system,
}

class ProcessLogEntry {
  final String taskId;
  final DateTime time;
  final LogStreamType streamType;
  final String text;

  const ProcessLogEntry({
    required this.taskId,
    required this.time,
    required this.streamType,
    required this.text,
  });
}
