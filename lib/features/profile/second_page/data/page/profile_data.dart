import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/profile/second_page/data/models/action_info.dart';
import 'package:torrid/features/profile/second_page/data/providers/status_provider.dart';
import 'package:torrid/features/profile/second_page/data/widgets/action_button.dart';
import 'package:torrid/features/profile/second_page/data/widgets/network_config_widget.dart';

class ProfileData extends ConsumerWidget {
  const ProfileData({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final List<ActionInfo> infos = ref.read(actionInfosProvider);

    return Container(
      child: ref.watch(dataServiceProvider)['isLoading']
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("稍等...", style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 网络地址输入框/状态栏
                    NetworkConfigWidget(),

                    // 同步相关操作
                    Text(
                      "同步到本地:",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    // 特殊的map(): expand, 其中每一元素返回零或多个元素的集合(之后再扁平合并)
                    ...infos.take((infos.length / 2).ceil()).expand((info) {
                      return [
                        const SizedBox(height: 8),
                        ActionButton(context: context, info: info),
                      ];
                    }),

                    const SizedBox(height: 24),

                    // 更新相关操作
                    Text(
                      "更新到外部:",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    ...infos.skip((infos.length / 2).ceil()).expand((info) {
                      return [
                        const SizedBox(height: 8),
                        ActionButton(context: context, info: info),
                      ];
                    }),
                  ],
                ),
              ),
            ),
    );
  }
}
