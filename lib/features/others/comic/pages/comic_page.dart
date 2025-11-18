import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/provider/notifier_provider.dart';
import 'package:torrid/features/others/comic/provider/status_provider.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';

class ComicPage extends ConsumerStatefulWidget {
  const ComicPage({super.key});

  @override
  ConsumerState<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends ConsumerState<ComicPage> {
  bool isLoading = false;

  Future<void> initInfos() async {
    setState(() {
      isLoading = true;
    });
    // await ref.read(comicServiceProvider.notifier).refreshInfo();
    await Future.delayed(Duration(seconds: 4));
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
        actions: [
          IconButton(
            onPressed: initInfos,
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildBody(comicInfos),
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
        // TODO: 显示最近阅读的漫画, 点击直接跳转.
        // const LatestReadDisplay(),
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
