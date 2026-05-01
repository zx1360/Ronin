import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class IndexedPreviewImage extends StatelessWidget {
  final String imageUrl;
  final int index;
  final double width;
  final double height;
  final double radius;
  final EdgeInsets badgePadding;
  final Alignment badgeAlignment;
  final Color? badgeColor;
  final Color? badgeTextColor;

  const IndexedPreviewImage({
    super.key,
    required this.imageUrl,
    required this.index,
    this.width = 64,
    this.height = 64,
    this.radius = 8,
    this.badgePadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    this.badgeAlignment = Alignment.topLeft,
    this.badgeColor,
    this.badgeTextColor,
  });

  Future<void> _showPreview(BuildContext context) async {
    if (imageUrl.isEmpty) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.8,
            child: PhotoView(
              imageProvider: NetworkImage(imageUrl),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (imageUrl.isEmpty) {
      return CircleAvatar(child: Text('$index'));
    }
    return GestureDetector(
      onDoubleTap: () => _showPreview(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.network(
              imageUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: badgeAlignment.y < 0 ? 4 : null,
            left: badgeAlignment.x < 0 ? 4 : null,
            right: badgeAlignment.x > 0 ? 4 : null,
            bottom: badgeAlignment.y > 0 ? 4 : null,
            child: Container(
              padding: badgePadding,
              decoration: BoxDecoration(
                color: badgeColor ?? cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$index',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: badgeTextColor ?? cs.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
