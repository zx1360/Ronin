import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_preference.dart';
import 'package:torrid/features/others/comic/provider/content_provider.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';

class RowInfoWidget extends ConsumerWidget {
  final String comicId;
  const RowInfoWidget({super.key, required this.comicId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comicPref =
        ref.watch(comicContentProvider)['comicPref']as ComicPreference;
    final isFlipMode = comicPref.flipReading;
    return Row(
      children: [
        const Text(
          '章节列表',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Spacer(),
        Text(isFlipMode ? "翻页阅读" : "下拉阅读"),
        Switch(
          value: isFlipMode,
          onChanged: (bool value) {
            ref
                .read(comicServiceProvider.notifier)
                .putComicPref(
                  comicPref: comicPref.copyWith(flipReading: value),
                );
          },
        ),
      ],
    );
  }
}
