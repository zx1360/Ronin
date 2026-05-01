import 'package:flutter/material.dart';
import 'package:torrid/features/others/lathe/pages/lathe_page.dart';
import 'package:torrid/features/others/widgets/entry_button.dart';

import 'package:torrid/features/others/comic/pages/comic_page.dart';
import 'package:torrid/features/others/gallery/pages/gallery_page.dart';

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
    // 倒计时页.
    PageItem(
      label: "倒计时",
      icon: Icons.timer,
      builder: (context) => LathePage(),
    ),
  ];
}
