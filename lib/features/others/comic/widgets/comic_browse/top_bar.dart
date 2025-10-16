import 'package:flutter/material.dart';

// TODO: riverpod重构!
class TopBar extends StatelessWidget {
  final String comicName;
  final String chapterName;
  final int currentNum;
  final int totalNum;
  const TopBar({
    super.key,
    required this.comicName,
    required this.chapterName,
    required this.currentNum,
    required this.totalNum,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        color: Colors.black54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    comicName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$chapterName (${currentNum + 1}/$totalNum)',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
