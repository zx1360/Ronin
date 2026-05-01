String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;

  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }

  final text = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  return '$text ${units[index]}';
}
