/// 对话页上的"近期回顾"入口。
///
/// 生成可能耗时几分钟；面板关掉后请求仍在进行（控制器是 keepAlive 的），
/// 因此入口按钮在生成期间显示转圈，避免"点了没反应"或"请求被悄悄丢掉"。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/review/providers/review_providers.dart';
import 'package:torrid/features/review/widgets/review_sheet.dart';

class ReviewEntryButton extends ConsumerWidget {
  const ReviewEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generating = ref.watch(
      reviewControllerProvider.select((state) => state.generating),
    );
    final foreground = IconTheme.of(context).color ?? Colors.white;

    return IconButton(
      tooltip: generating ? '近期回顾（生成中…）' : '近期回顾',
      onPressed: () => showReviewSheet(context),
      icon: generating
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(foreground),
              ),
            )
          : const Icon(Icons.insights_outlined),
    );
  }
}
