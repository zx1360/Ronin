import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/features/read/views/entertainment/sentence_tab.dart';

class EntertainmentView extends ConsumerWidget {
  const EntertainmentView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SentenceTab();
  }
}
