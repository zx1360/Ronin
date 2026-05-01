import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/essay/widgets/detail/essay_content_widget.dart';
import 'package:torrid/features/essay/widgets/detail/message_input_widget.dart';
import 'package:torrid/features/essay/widgets/modify/retag_widget.dart';

class EssayDetailPage extends ConsumerWidget {
  const EssayDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainer,
        foregroundColor: AppTheme.onSurface,
        elevation: 1,
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: AppTheme.onSurface),
        centerTitle: true,
        // 底部分割线
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppTheme.outline.withAlpha(77), height: 1),
        ),
        title: const Text('随笔详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showModify(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EssayContentWidget(),

            const SizedBox(height: 24),

            // 添加留言
            const MessageInputWidget(),
          ],
        ),
      ),
    );
  }

  void _showModify(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => RetagWidget(),
    );
  }
}
