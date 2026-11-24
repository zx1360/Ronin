import 'package:flutter/material.dart';
import 'package:torrid/features/others/widgets/entry_button.dart';

import 'package:torrid/features/comic/pages/comic_page.dart';
import 'package:torrid/features/gallery/pages/gallery_page.dart';
import 'package:torrid/features/album/pages/album_page.dart';

class OtherPagesData {
  static List<PageItem> get pages => [
    PageItem(
      label: "漫画",
      description: '阅读、下载与离线收藏',
      icon: const IconData(0xe600, fontFamily: "iconfont"),
      builder: (context) => ComicPage(),
    ),
    PageItem(
      label: "藏品",
      description: '离线整理与媒体标注',
      icon: Icons.collections_bookmark_outlined,
      builder: (context) => GalleryPage(),
    ),
    PageItem(
      label: "相册",
      description: '在线浏览、标签与检索',
      icon: Icons.photo_album,
      builder: (context) => const AlbumPage(),
    ),
  ];
}
