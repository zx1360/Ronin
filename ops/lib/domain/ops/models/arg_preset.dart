import 'package:northstar/domain/ops/utils/arg_parser.dart';

class ArgPreset {
  final String id;
  final String name;
  final List<String> args;

  const ArgPreset({required this.id, required this.name, required this.args});

  String get argsText {
    if (args.isEmpty) {
      return '(无参数)';
    }
    return toArgumentLine(args);
  }

  factory ArgPreset.fromJson(Map<String, dynamic> json) {
    return ArgPreset(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      args: ((json['args'] as List?) ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'args': args};
  }
}
