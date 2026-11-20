import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class CommonImageWidget extends ConsumerWidget {
  final String imageUrl;
  final bool isLocal;
  const CommonImageWidget({
    super.key,
    required this.imageUrl,
    required this.isLocal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget cover;
    if (imageUrl.isEmpty) {
      cover = _placeholder();
    } else if (isLocal) {
      cover = Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } else {
      final apiClient = ref.watch(apiClientManagerProvider);
      cover = Image.network(
        '${apiClient.baseUrl}/static/$imageUrl',
        headers: apiClient.headers,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: cover);
  }

  Widget _placeholder() => ColoredBox(
    color: Colors.grey.shade200,
    child: const Center(child: Icon(Icons.book, color: Colors.grey, size: 30)),
  );
}
