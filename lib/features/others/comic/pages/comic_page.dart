import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torrid/features/others/comic/models/comic_info.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/features/others/comic/widgets/overview_page/comic_item.dart';
import 'package:torrid/services/io/io_service.dart';

class ComicPage extends StatefulWidget {
  const ComicPage({super.key});

  @override
  State<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends State<ComicPage> {
  List<ComicInfo> _comics = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadComics();
  }

  Future<void> _checkPermissionsAndLoadComics() async {
    // 检查存储权限，适配Android 13+的存储权限
    Permission permission =
        Platform.isAndroid && await Permission.storage.isDenied
        ? Permission.photos
        : Permission.storage;

    // 请求权限
    final status = await permission.request();

    if (status.isGranted) {
      _loadComics();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "需要存储权限才能访问漫画资源";
      });
    }
  }

  Future<void> _loadComics() async {
    try {
      // 获取应用外部私有目录
      final externalDir = await IoService.externalStorageDir;

      final comicsDir = Directory("${externalDir.path}/comics");

      // 检查漫画目录是否存在
      if (!await comicsDir.exists()) {
        setState(() {
          _isLoading = false;
          _errorMessage = "未找到漫画资源，请在${comicsDir.path}目录下添加漫画";
        });
        return;
      }

      // 列出所有漫画文件夹
      final comicFolders = await comicsDir
          .list()
          .where((entity) => entity is Directory)
          .toList();

      List<ComicInfo> comics = [];

      for (var folder in comicFolders) {
        final dir = folder as Directory;
        final comicName = dir.path.split(Platform.pathSeparator).last;

        // TODO: 查找封面图（第一个找到的图片）
        File? coverImage = await findFirstImage(dir);
        // 获取章节数
        final chapters = await countChapters(dir);
        // 获取总图片数
        final totalImages = await countTotalImages(dir);

        comics.add(
          ComicInfo.newOne(
            comicName: comicName,
            coverImage: coverImage?.path??"",
            chapterCount: chapters,
            imageCount: totalImages,
          ),
        );
      }

      setState(() {
        _comics = comics;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "加载漫画失败: ${e.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本地漫画'), centerTitle: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkPermissionsAndLoadComics,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_comics.isEmpty) {
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
            itemCount: _comics.length,
            itemBuilder: (context, index) {
              final comic = _comics[index];
              return ComicItem(comic: comic);
            },
          ),
        ),
      ],
    );
  }
}
