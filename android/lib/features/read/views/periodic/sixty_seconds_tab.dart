import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';
import 'package:torrid/core/constants/spacing.dart';

class SixtySecondsTab extends ConsumerStatefulWidget {
  const SixtySecondsTab({super.key});
  @override
  ConsumerState<SixtySecondsTab> createState() => _SixtySecondsTabState();
}

class _SixtySecondsTabState extends ConsumerState<SixtySecondsTab> {
  DateTime _selected = DateTime.now();

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_selected);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final min = now.subtract(const Duration(days: 180));
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected.isBefore(min) || _selected.isAfter(now)
          ? now
          : _selected,
      firstDate: min,
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = sixtySecondsProvider(_dateStr);
    final async = ref.watch(provider);
    return Column(
      children: [
        const SectionTitle(title: '日期选择', icon: Icons.calendar_month),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_dateStr),
              OutlinedButton(onPressed: _pickDate, child: const Text('选择日期')),
              TextButton(
                onPressed: () => setState(() => _selected = DateTime.now()),
                child: const Text('重置为今天'),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              '60秒读懂世界加载失败：$e',
              onRetry: () => ref.invalidate(provider),
            ),
            data: (data) {
              final news = (data['news'] as List).whereType<String>();
              final image = (feedUri(data['image']) ?? feedUri(data['cover']))
                  ?.toString();
              final tip = feedText(data['tip']);
              final link = feedUri(data['link'])?.toString();
              return RefreshIndicator(
                onRefresh: () =>
                    waitForFeedRefresh(ref.refresh(provider.future)),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (image != null) const SectionTitle(title: '封面'),
                    if (image != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Center(child: Text('封面暂时无法加载')),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      showImagePreview(context, image),
                                  icon: const Icon(Icons.fullscreen),
                                  label: const Text('查看大图'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SectionTitle(title: '要闻'),
                    if (news.isEmpty) const ErrorView('暂无当天要闻'),
                    ...news.map(
                      (n) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              n.toString(),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (tip != null) const SectionTitle(title: 'Tip'),
                    if (tip != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.lightbulb),
                            title: Text(tip),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () =>
                                  Clipboard.setData(ClipboardData(text: tip)),
                            ),
                          ),
                        ),
                      ),
                    if (link != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: link)),
                          icon: const Icon(Icons.link),
                          label: const Text('复制原文链接'),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
