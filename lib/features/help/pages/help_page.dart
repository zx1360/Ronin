import 'package:flutter/material.dart';
import 'package:northstar/app/theme.dart';
import 'package:northstar/shared/widgets/heading/heading.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Heading(title: '帮助'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.paddingL),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Northstar 本地运维控制台'),
                    SizedBox(height: 8),
                    Text('1. 在设置页配置 API Base URL、API Key 和轮询间隔。'),
                    Text('2. 在任务管理页为每个任务设置 exe 路径和工作目录。'),
                    Text('3. 启动任务后可在日志页查看 stdout/stderr 实时输出。'),
                    Text('4. 危险任务会要求输入确认短语。'),
                    Text('5. 关闭应用时，若有任务运行会提示是否终止进程。'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}