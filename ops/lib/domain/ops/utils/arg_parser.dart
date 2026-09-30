List<String> parseArgumentLine(String input) {
  final result = <String>[];
  final buffer = StringBuffer();
  var inQuote = false;

  for (var i = 0; i < input.length; i++) {
    final char = input[i];

    if (char == '"') {
      inQuote = !inQuote;
      continue;
    }

    if (!inQuote && char.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }

    buffer.write(char);
  }

  if (buffer.isNotEmpty) {
    result.add(buffer.toString());
  }

  return result;
}

String toArgumentLine(List<String> args) {
  return args.map((arg) {
    if (arg.contains(' ')) {
      return '"$arg"';
    }
    return arg;
  }).join(' ');
}
