import 'package:flutter/material.dart';
import 'package:torrid/features/others/widgets/entry_button.dart';

import 'package:torrid/features/others/comic/pages/comic_page.dart';
import 'package:torrid/features/others/gallery/pages/gallery_page.dart';
import 'package:torrid/features/others/immich/pages/immich_page.dart';
import 'package:torrid/features/others/smart_album/pages/smart_album_page.dart';

class OtherPagesData {
  static List<PageItem> get pages => [
    // 漫画页
    PageItem(
      label: "漫画",
      icon: const IconData(0xe600, fontFamily: "iconfont"),
      builder: (context) => ComicPage(),
    ),
    // 战利品页.
    PageItem(
      label: "藏品",
      icon: Icons.assessment,
      builder: (context) => GalleryPage(),
    ),
    // 相册页 (immich, 需在线使用; 人工标签 + 只读 AI 标签).
    PageItem(
      label: "相册",
      icon: Icons.photo_album,
      builder: (context) => const ImmichPage(),
    ),
    // 智能相册页 (AI检索: 语义/文字/文件名检索, 人物分组).
    PageItem(
      label: "智能相册",
      icon: Icons.auto_awesome,
      builder: (context) => const SmartAlbumPage(),
    ),
  ];
}
