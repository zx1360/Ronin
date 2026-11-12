import 'package:flutter/material.dart';

import 'package:torrid/features/read/views/media/image_tab.dart';
import 'package:torrid/features/read/views/media/video_tab.dart';

class MediaView extends StatelessWidget {
  const MediaView({super.key, required this.sectionIndex});

  final int sectionIndex;

  @override
  Widget build(BuildContext context) {
    final sections = DefaultTabController.of(context);
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Column(
            children: [
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: '图片'),
                  Tab(text: '视频'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    const ImageTab(),
                    ListenableBuilder(
                      listenable: Listenable.merge([sections, tabs]),
                      builder: (context, _) => VideoTab(
                        active:
                            sections.index == sectionIndex && tabs.index == 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
