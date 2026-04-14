import 'package:flutter_test/flutter_test.dart';
import 'package:northstar/domain/ops/utils/arg_parser.dart';
import 'package:northstar/domain/ops/utils/format_utils.dart';

void main() {
  test('formatBytes returns readable unit', () {
    expect(formatBytes(1024), '1.00 KB');
    expect(formatBytes(1024 * 1024), '1.00 MB');
  });

  test('parseArgumentLine supports quoted values', () {
    final args = parseArgumentLine('-mode ingest -gallery-root "D:\\Assets\\Gallery Root"');
    expect(args, <String>['-mode', 'ingest', '-gallery-root', 'D:\\Assets\\Gallery Root']);
  });
}
