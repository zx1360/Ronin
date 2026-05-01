import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:torrid/core/constants/spacing.dart';
import 'package:torrid/core/services/io/io_service.dart';

class ChangyaUserLine extends StatelessWidget {
  final String? avatarUrl;
  final String nickname;
  final String gender;
  const ChangyaUserLine({super.key, required this.avatarUrl, required this.nickname, required this.gender});

  @override
  Widget build(BuildContext context) {
    ImageProvider? provider;
    final u = avatarUrl ?? '';
    if (u.startsWith('http')) {
      provider = NetworkImage(u);
    } else if (u.startsWith('/')) {
      return FutureBuilder<String>(
        future: _resolveLocal(u),
        builder: (context, snap) {
          final has = (snap.data ?? '').isNotEmpty;
          return Row(
            children: [
              CircleAvatar(radius: 22, backgroundImage: has ? FileImage(File(snap.data!)) : null, child: has ? null : const Icon(Icons.person)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('性别: $gender', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }
    return Row(
      children: [
        CircleAvatar(radius: 22, backgroundImage: provider, child: provider == null ? const Icon(Icons.person) : null),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nickname, style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('性别: $gender', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Future<String> _resolveLocal(String rel) async {
    final base = (await IoService.externalStorageDir).path;
    return p.normalize(p.join(base, rel.replaceFirst('/', '')));
  }
}
