import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/providers/status_provider.dart';
import 'package:torrid/features/essay/widgets/label_style.dart';
import 'package:torrid/core/widgets/file_img_builder/file_img_builder.dart';
import 'package:torrid/core/widgets/mood_selector/mood_selector.dart';

class EssayCard extends ConsumerWidget {
  final Essay essay;
  final VoidCallback onTap;

  const EssayCard({super.key, required this.essay, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idMap = ref.watch(idMapProvider);

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelPaths = essay.labels
        .map((id) => idMap[id])
        .whereType<String>()
        .toList();
    final preview = essay.content
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .characters
        .take(160)
        .toString();
    return Material(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MM月dd日').format(essay.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (essay.mood != null)
                    MoodDisplay(mood: essay.mood, iconSize: 16),
                ],
              ),
              if (essay.title.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  essay.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  preview,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (essay.imgs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < essay.imgs.length && i < 3; i++)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            FileImageBuilder(
                              relativeImagePath: essay.imgs[i],
                              size: 64,
                            ),
                            if (i == 2 && essay.imgs.length > 3)
                              Positioned.fill(
                                child: ColoredBox(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Text(
                                      '+${essay.imgs.length - 3}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (labelPaths.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final path in labelPaths) EssayLabelChip(path: path),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    essay.wordCountText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (essay.messages.isNotEmpty) ...[
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 13,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${essay.messages.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
