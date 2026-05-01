import 'dart:io';

import 'package:flutter/material.dart';
import 'package:torrid/core/services/io/io_service.dart';

class FileImageBuilder extends StatelessWidget {
  final String relativeImagePath;
  final bool isOriginScale;
  final double size;
  const FileImageBuilder({
    super.key,
    required this.relativeImagePath,
    this.isOriginScale=false,
    this.size=60,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: IoService.getImageFile(relativeImagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            // 是否原尺寸展示
            return isOriginScale?
            Image.file(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: size,
                  height: size,
                  color: Colors.yellow.shade200,
                  child: Icon(Icons.task, color: Colors.yellow.shade700),
                );
              },
            ):
            Image.file(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: size,
                  height: size,
                  color: Colors.yellow.shade200,
                  child: Icon(Icons.task, color: Colors.yellow.shade700),
                );
              },
            );
          }
        }
        return Container(
          width: size,
          height: size,
          color: Colors.yellow.shade200,
          child: snapshot.connectionState == ConnectionState.waiting
              ? const CircularProgressIndicator(strokeWidth: 2)
              : Icon(Icons.task, color: Colors.yellow.shade700),
        );
      },
    );
  }
}
