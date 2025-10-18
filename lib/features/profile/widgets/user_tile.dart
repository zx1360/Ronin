// 用户信息部分
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserTile extends StatelessWidget {
  const UserTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(  //TODO: vertical: 20
        leading: const CircleAvatar(
          radius: 30,
          backgroundImage: AssetImage("assets/icons/six.png"),
        ),

        // TODO: 后期ref获取.
        title: Text(
          "昵称: 谁才是超级小马",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          "签名: 我将如闪电般归来.",
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 18,
        ),
        onTap: () {
          context.pushNamed("profile_user");
        },
      );
  }
}
