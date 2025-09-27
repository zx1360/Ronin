import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavInfo {
  final String title;
  final String subtitle;
  final IconData icon;
  final String childRouteName;

  NavInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.childRouteName,
  });
}

class NavTile extends StatelessWidget {
  final NavInfo info;
  const NavTile({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: ListTile(
        leading: Icon(info.icon, color: Colors.grey[600]),
        title: Text(info.title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(
          info.subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Colors.grey,
        ),
        onTap: () => context.pushNamed(
          info.childRouteName,
          extra: {"title": info.title},
        ),
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
