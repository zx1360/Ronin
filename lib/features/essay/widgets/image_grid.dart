import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/core/services/io/io_service.dart';

class ImageGrid extends StatelessWidget {
  final List<String> images;

  const ImageGrid({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<File?>(
            future: IoService.getImageFile(images[index]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasData) {
                  return Image.file(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.yellow.shade200,
                        child: Icon(Icons.task, color: Colors.yellow.shade700),
                      );
                    },
                  );
                }
              }
              return Container(
                width: 60,
                height: 60,
                color: Colors.yellow.shade200,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Icon(Icons.task, color: Colors.yellow.shade700),
              );
            },
          ),
        );
      },
    );
  }
}
