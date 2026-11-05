import 'package:flutter/material.dart';
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/modals/snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> waitForFeedRefresh(Future<Object?> pending) async {
  try {
    await pending;
  } catch (_) {
    // 请求结果由页面的 AsyncValue 渲染。
  }
}

String? feedText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;

Uri? feedUri(Object? value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.host.isEmpty ||
      !['http', 'https'].contains(uri.scheme)) {
    return null;
  }
  return uri;
}

Future<void> openFeedLink(BuildContext context, Uri uri) async {
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // 打开失败时统一提示。
  }
  if (context.mounted) displaySnackBar(context, '无法打开链接');
}

class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const SectionTitle({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: cs.primary),
          if (icon != null) const SizedBox(width: AppSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(child: CircularProgressIndicator(color: cs.primary));
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView(this.message, {super.key, this.onRetry});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: cs.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
