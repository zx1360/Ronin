import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';
import 'package:torrid/shared/modals/choice_modal.dart';
import 'package:torrid/shared/modals/dialog_option.dart';
import 'package:torrid/shared/widgets/progress_indicator.dart';

class ComicPage extends ConsumerStatefulWidget {
  const ComicPage({super.key});

  @override
  ConsumerState<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends ConsumerState<ComicPage> {
  bool isLoading = false;

  Future<void> initInfos() async {
    final option = await showOptionsDialog(
      context: context,
      title: "初始化漫画文件元数据.",
      content: "初始化方式:",
      options: [
        DialogOption(
          text: "全部重新初始化",
          textColor: Colors.red[300],
          onPressed: () async {
            await ref.read(comicServiceProvider.notifier).refreshInfo(false);
          },
        ),
        DialogOption(
          text: "仅增量更新",
          onPressed: () async {
            await ref.read(comicServiceProvider.notifier).refreshInfo(true);
          },
        ),
      ],
    );
    if (option == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });
    await option.onPressed();
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final comicInfos = ref.watch(comicInfosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地漫画'),
        centerTitle: true,
        actions: [IconButton(onPressed: initInfos, icon: Icon(Icons.refresh))],
      ),
      body: isLoading ? ProgressIndicatorWidget() : _buildBody(comicInfos),
    );
  }

  Widget _buildBody(List<ComicInfo> comics) {
    if (comics.isEmpty) {
      return const Center(
        child: Text('未找到任何漫画', style: TextStyle(fontSize: 18)),
      );
    }

    // 网格布局展示漫画，使用等高等宽设置
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1, // 等宽等高
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: comics.length,
            itemBuilder: (context, index) {
              final comic = comics[index];
              return ComicItem(comicInfo: comic);
            },
          ),
        ),
      ],
    );
  }
}
