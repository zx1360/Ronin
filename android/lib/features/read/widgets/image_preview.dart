import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

Future<void> showImagePreview(
  BuildContext context,
  String imageUrl, {
  Map<String, String>? headers,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(0),
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PhotoView(
            imageProvider: NetworkImage(imageUrl, headers: headers),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            errorBuilder: (_, _, _) => const Center(
              child: Text('图片暂时无法加载', style: TextStyle(color: Colors.white)),
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}
