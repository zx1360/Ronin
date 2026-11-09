import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/features/essay/widgets/detail/essay_content_widget.dart';
import 'package:torrid/features/essay/widgets/detail/message_input_widget.dart';
import 'package:torrid/features/essay/widgets/modify/retag_widget.dart';

class EssayDetailPage extends ConsumerWidget {
  final String essayId;
  const EssayDetailPage({super.key, required this.essayId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final essay = ref.watch(essayByIdProvider(essayId));
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
            tooltip: '编辑标签',
            icon: const Icon(Icons.label_outline),
            onPressed: essay.valueOrNull == null
                ? null
                : () => _showModify(context),
          ),
        ],
      ),
      body: essay.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('读取失败：$error')),
        data: (essay) => essay == null
            ? const Center(child: Text('随笔已不存在'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EssayContentWidget(essay: essay),
                    const SizedBox(height: 24),
                    MessageInputWidget(essayId: essayId),
                  ],
                ),
              ),
      ),
    );
  }

  void _showModify(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 180),
        child: RetagWidget(essayId: essayId),
      ),
    );
  }
}
