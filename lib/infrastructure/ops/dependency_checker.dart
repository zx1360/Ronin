import 'dart:io';

class DependencyChecker {
  Future<List<String>> findMissingCommands(List<String> commands) async {
    final missing = <String>[];

    for (final command in commands) {
      final result = await Process.run('where', <String>[command]);
      if (result.exitCode != 0) {
        missing.add(command);
      }
    }

    return missing;
  }
}
