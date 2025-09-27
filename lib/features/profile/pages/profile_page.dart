import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/features/profile/widgets/nav_tile.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 各详细页的相关信息
  final List<NavInfo> infos = NavTileDatas.datas;

  // 模拟设置项状态
  bool _notificationsEnabled = true;

  // 模拟用户信息
  final String _username = "昵称: 谁才是超级小马";
  final String _email = "签名: 我将如闪电般归来.";


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 设置页面导航栏
      appBar: AppBar(
        // 沉浸式状态栏
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        elevation: 1,
      ),

      // 主内容区域
      body: ListView(
        children: [
          // 用户信息区域
          _buildUserProfileSection(),

          // 主要设置区域
          _buildMainSettingsSection(),

          // 其他设置区域
          _buildOtherSettingsSection(),

          // 关于区域
          _buildAboutSection(),

          // 底部间距
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 用户信息部分
  Widget _buildUserProfileSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: ListTile(
        leading: const CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(
            'https://img2.huashi6.com/images/resource/thumbnail/2025/07/22/22311_66194159821.jpg?imageMogr2/quality/100/interlace/1/thumbnail/2000x%3E',
          ),
          backgroundColor: Colors.grey,
        ),
        title: Text(
          _username,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _email,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Colors.grey,
        ),
        onTap: () {
          // 跳转到个人资料页面
          context.pushNamed("profile_user", extra: {
            "title": "个人信息"
          });
        },
      ),
    );
  }

  // 主要设置部分
  Widget _buildMainSettingsSection() {
    return Column(
      children: [
        _buildSectionTitle('主要设置'),

        // 通知设置
        _buildSwitchListTile(
          title: '通知',
          subtitle: '接收应用通知',
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
          icon: Icons.notifications,
        ),
      ],
    );
  }

  // 其他设置部分
  Widget _buildOtherSettingsSection() {
    return Column(
      children: [
        _buildSectionTitle('其他设置'),

        // 首选项设置
        NavTile(info: infos[0]),

        // 数据相关
        NavTile(info: infos[1]),

        // 账号相关
        NavTile(info: infos[2]),
      ],
    );
  }

  // 关于部分
  Widget _buildAboutSection() {
    return Column(
      children: [
        _buildSectionTitle('关于'),

        // 帮助相关
        NavTile(info: infos[3]),

        // 应用相关
        NavTile(info: infos[4]),

        // 退出登录
        _buildActionListTile(
          title: '退出登录',
          icon: Icons.logout,
          textColor: Colors.red,
          onTap: () => _showLogoutDialog(),
        ),
      ],
    );
  }

  // 构建分组标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 构建带开关的列表项
  Widget _buildSwitchListTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey[600]),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Theme.of(context).primaryColor,
        ),
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  // 构建带操作的列表项（如退出登录）
  Widget _buildActionListTile({
    required String title,
    required IconData icon,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(fontSize: 16, color: textColor)),
        onTap: onTap,
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  // 显示退出登录对话框
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 执行退出登录操作
              Navigator.pop(context);
              // 这里可以添加退出登录的逻辑
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
