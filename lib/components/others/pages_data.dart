import 'package:flutter/material.dart';
import 'package:torrid/components/others/entry_button.dart';
import 'package:torrid/pages/others/ideas/ideas_page.dart';
import 'package:torrid/pages/others/notes/notes_page.dart';

import 'package:torrid/pages/others/realm/realm_page.dart';
import 'package:torrid/pages/others/tuntun/tuntun_page.dart';
import 'package:torrid/pages/others/viewhub/viewhub_page.dart';

class OtherPagesData {
  static List<PageItem> get pages => [
    // 笔记页.
    PageItem(
      label: "笔记",
      icon: Icons.note_alt_sharp,
      builder: (context) => NotesPage(),
    ),
    // 幻想页
    PageItem(
      label: "主意",
      icon: Icons.wb_incandescent_sharp,
      builder: (context) => IdeasPage(),
    ),

    // 影视页, 媒体查看.
    PageItem(
      label: "媒体",
      icon: Icons.grid_view,
      builder: (context) => ViewhubPage(),
    ),
    // 战利品页.
    PageItem(
      label: "藏品",
      icon: Icons.assessment,
      builder: (context) => TuntunPage(),
    ),


    // 世界观/主支线剧情体验
    PageItem(
      label: "领域",
      icon: Icons.category,
      builder: (context) => RealmPage(),
    ),
  ];
}
