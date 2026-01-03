import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/utils/file_relates.dart';
import 'package:torrid/core/utils/util.dart';
import 'package:torrid/features/read/widgets/common.dart';
import 'package:torrid/features/read/widgets/image_preview.dart';
import 'package:torrid/features/read/providers/sixty_api_provider.dart';
import 'package:torrid/core/constants/spacing.dart';

class BingWallpaperTab extends ConsumerWidget {
  const BingWallpaperTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bingWallpaperProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView('必应壁纸加载失败：$e'),
      data: (data) {
        final cover = data['cover'] as String?;
        final cover4k = data['cover_4k'] as String?;
        final title = data['title'] as String?;
        final headline = data['headline'] as String?;
        final desc = data['description'] as String?;
        final mainText = data['main_text'] as String?;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bingWallpaperProvider);
          },
          child: ListView(
            children: [
              if (title != null)
                const SectionTitle(title: '必应每日壁纸', icon: Icons.image),
              if (title != null || headline != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      if (headline != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          headline,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              if (cover != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => showImagePreview(context, cover),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(cover, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              if (cover4k != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () => showImagePreview(context, cover4k),
                        icon: const Icon(Icons.hd),
                        label: const Text('查看 4K'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _downloadImageUsingClient(
                            context,
                            ref,
                            cover4k,
                            (title ?? 'bing_4k'),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('下载 4K 到本地'),
                      ),
                    ],
                  ),
                ),
              if (cover != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await _downloadImageUsingClient(
                            context,
                            ref,
                            cover,
                            (title ?? 'bing_cover'),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('下载封面到本地'),
                      ),
                    ],
                  ),
                ),
              if (desc != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    desc,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              if (mainText != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Text(
                    mainText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _downloadImageUsingClient(
  BuildContext context,
  WidgetRef ref,
  String url,
  String fileBaseName,
) async {
  try {
    final client = ref.read(sixtyApiClientProvider);
    final resp = await client.getBinary(url);
    final bytes = resp.data;
    if (bytes == null || bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片下载失败：无数据')));
      }
      return;
    }

    final dir = await IoService.externalStorageDir;
    final fileName =
        '${sanitizeDirectoryName(fileBaseName.replaceAll(' ', '_'))}_${getTodayDateString()}.jpg';
    final file = File(p.join(dir.path, "api_medias", fileName));

    if (await file.exists()) {
      await file.delete();
    }
    await IoService.ensureDirExists("api_medias");
    await file.writeAsBytes(bytes);
    displaySnackBar(context, '已保存到：${file.path}');
  } catch (e) {
    displaySnackBar(context, '下载出错：$e');
  }
}
