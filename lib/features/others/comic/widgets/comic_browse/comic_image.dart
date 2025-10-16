import 'dart:io';

import 'package:flutter/material.dart';

class ComicImage extends StatelessWidget {
  final String path;
  const ComicImage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: double.infinity,
      fit: BoxFit.fitWidth,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 64,
          color: Colors.black12,
          child: const Center(
            child: Icon(Icons.error, color: Colors.red, size: 40),
          ),
        );
      },
    );
  }
}