// 用户信息部分
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

class UserTile extends ConsumerWidget {
  const UserTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: _buildAvatar(settings.avatarPath),
        title: Text(
          settings.nickname,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          settings.signature,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
        onTap: () {
          context.pushNamed("profile_user");
        },
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(String? avatarPath) {
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return FutureBuilder<File?>(
        future: IoService.getImageFile(avatarPath),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return CircleAvatar(
              radius: 30,
              backgroundImage: FileImage(snapshot.data!),
              onBackgroundImageError: (_, __) {},
              child: null,
            );
          }
          return _defaultAvatar();
        },
      );
    }
    return _defaultAvatar();
  }

  /// 默认头像
  Widget _defaultAvatar() {
    return const CircleAvatar(
      radius: 30,
      backgroundImage: AssetImage("assets/icons/six.png"),
    );
  }
}
