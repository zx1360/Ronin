import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:torrid/features/essay/models/essay_search.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';

part 'search_provider.g.dart';

@riverpod
Future<EssaySearchIndex> essaySearchIndex(EssaySearchIndexRef ref) async {
  final essays = await ref.watch(filteredEssaysProvider.future);
  return compute(EssaySearchIndex.new, essays);
}
