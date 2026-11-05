import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/storage/public_storage_service.dart';
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
      error: (e, _) => ErrorView(
        '必应壁纸加载失败：$e',
        onRetry: () => ref.invalidate(bingWallpaperProvider),
      ),
      data: (data) {
        final cover4k = feedUri(data['cover_4k'])?.toString();
        final cover = feedUri(data['cover'])?.toString() ?? cover4k;
        final title = feedText(data['title']);
        final headline = feedText(data['headline']);
        final desc = feedText(data['description']);
        final mainText = feedText(data['main_text']);
        return RefreshIndicator(
          onRefresh: () =>
              waitForFeedRefresh(ref.refresh(bingWallpaperProvider.future)),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        child: Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('壁纸暂时无法加载')),
                        ),
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
                            ("${title ?? 'bing'}_4k"),
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
                            ("${title ?? 'bing'}_cover"),
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

    final fileName = PublicStorageService.generateDateFileName(
      fileBaseName,
      'jpg',
    );
    final file = await PublicStorageService.saveBytes(
      subDir: PublicStorageService.dirBing,
      fileName: fileName,
      bytes: bytes,
    );

    if (file != null) {
      if (context.mounted) displaySnackBar(context, '已保存到：${file.location}');
    } else {
      if (context.mounted) displaySnackBar(context, '保存失败，请检查存储权限');
    }
  } catch (e) {
    if (context.mounted) {
      displaySnackBar(context, '下载出错：${ApiClient.mapError(e)}');
    }
  }
}
