import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/features/profile/datas/nav_tile_datas.dart';

class NavTile extends StatelessWidget {
  final BuildContext context;
  final ProfilePageConfig config;
  const NavTile({super.key, required this.context, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: ListTile(
        leading: Icon(config.icon, color: Colors.grey[600]),
        title: Text(config.title, style: const TextStyle(fontSize: 16)),
        subtitle: Text(
          config.subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
          color: Colors.grey,
        ),
        onTap: () =>
            context.pushNamed(config.name, extra: {'title': config.title}),
        minLeadingWidth: 24,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
