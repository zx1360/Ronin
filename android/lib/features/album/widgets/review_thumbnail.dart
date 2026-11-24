import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

String mediaFileName(String path) => path.split(RegExp(r'[/\\]')).last;

class ReviewThumbnail extends ConsumerWidget {
  const ReviewThumbnail({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientManagerProvider);
    const placeholder = Center(child: Icon(Icons.image_not_supported_outlined));
    if (api.baseUrl.isEmpty) return placeholder;

    Widget image(String type, ImageErrorWidgetBuilder onError) => Image(
      image: ResizeImage(
        CachedNetworkImageProvider(
          '${api.baseUrl}/API/gallery/$id/$type',
          headers: api.headers,
        ),
        width: 256,
        height: 256,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.contain,
      errorBuilder: onError,
    );

    return image(
      'preview',
      (_, _, _) => image('thumb', (_, _, _) => placeholder),
    );
  }
}
