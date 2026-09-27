import 'package:flutter/material.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';
import 'package:torrid/features/profile/widgets/nav_tile.dart';
import 'package:torrid/features/profile/widgets/section_tile.dart';
import 'package:torrid/features/profile/widgets/user_tile.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '个人',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        elevation: 1,
      ),

      // 主内容区域
      body: ListView(
        children: [
          // 用户信息区域
          UserTile(),

          // 设置区域
          SectionTile(
            title: "设置",
            children: settingPages
                .map((c) => NavTile(context: context, config: c))
                .toList(),
          ),

          // 关于区域
          SectionTile(
            title: "关于",
            children: aboutPages
                .map((c) => NavTile(context: context, config: c))
                .toList(),
          ),

          // 底部间距
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
