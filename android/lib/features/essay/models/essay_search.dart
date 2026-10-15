import 'dart:math' as math;

import 'package:torrid/features/essay/models/essay.dart';

class EssaySearchQuery {
  final List<String> terms;
  // 编译并复用字面量匹配器，减少长中文文本的查询耗时。
  late final List<RegExp> _matchers = [
    for (final term in terms) RegExp(RegExp.escape(term), unicode: true),
  ];
  late final RegExp pattern = RegExp(
    (List<String>.of(terms)..sort((a, b) => b.length.compareTo(a.length)))
        .map(RegExp.escape)
        .join('|'),
    caseSensitive: false,
    unicode: true,
  );

  EssaySearchQuery(String text)
    : terms = text
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toSet()
          .toList();

  bool get isEmpty => terms.isEmpty;

  ({String text, bool fromMessage}) excerpt(Essay essay) {
    var source = essay.content;
    var match = pattern.firstMatch(source);
    var fromMessage = false;
    if (match == null) {
      for (final message in essay.messages) {
        final hit = pattern.firstMatch(message.content);
        if (hit == null) continue;
        source = message.content;
        match = hit;
        fromMessage = true;
        break;
      }
    }
    var start = math.max(0, (match?.start ?? 0) - 32);
    var end = math.min(source.length, start + 180);
    // 截取 UTF-16 文本时保留完整的 emoji 等代理对。
    if (start > 0 && _isLowSurrogate(source.codeUnitAt(start))) {
      start--;
    }
    if (end < source.length && _isLowSurrogate(source.codeUnitAt(end))) {
      end++;
    }
    final text = source.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
    return (
      text: '${start > 0 ? '…' : ''}$text${end < source.length ? '…' : ''}',
      fromMessage: fromMessage,
    );
  }

  bool _isLowSurrogate(int unit) => unit >= 0xdc00 && unit <= 0xdfff;
}

class EssaySearchIndex {
  final List<({Essay essay, String text})> _documents;

  EssaySearchIndex(List<Essay> essays)
    : _documents = [
        for (final essay in essays)
          (
            essay: essay,
            text: [
              essay.title,
              essay.content,
              ...essay.messages.map((message) => message.content),
            ].join('\n').toLowerCase(),
          ),
      ];

  List<Essay> search(EssaySearchQuery query) {
    if (query.isEmpty) return const [];
    return [
      for (final document in _documents)
        if (query._matchers.every((pattern) => pattern.hasMatch(document.text)))
          document.essay,
    ];
  }
}
