import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'comic_detail.dart';

class HubComicPage extends StatefulWidget {
  const HubComicPage({super.key});

  @override
  State<HubComicPage> createState() => _HubComicPageState();
}

class _HubComicPageState extends State<HubComicPage> {
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
    Permission permission = Platform.isAndroid && await Permission.storage.isDenied
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
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception("无法访问外部存储");
      }

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
      final comicFolders = await comicsDir.list().where((entity) => entity is Directory).toList();
      
      List<ComicInfo> comics = [];
      
      for (var folder in comicFolders) {
        final dir = folder as Directory;
        final comicName = dir.path.split(Platform.pathSeparator).last;
        
        // 查找封面图（第一个找到的图片）
        File? coverImage = await _findFirstImage(dir);
        
        // 获取章节数
        final chapters = await _countChapters(dir);
        
        // 获取总图片数
        final totalImages = await _countTotalImages(dir);
        
        comics.add(ComicInfo(
          name: comicName,
          path: dir.path,
          coverImage: coverImage?.path,
          chapterCount: chapters,
          totalImages: totalImages,
        ));
      }

      // 按名称排序
      comics.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _comics = comics;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "加载漫画失败: ${e.toString()}";
      });
    }
  }

  // 查找目录中的第一张图片
  Future<File?> _findFirstImage(Directory dir) async {
    try {
      // 递归查找第一个图片文件
      await for (var entity in dir.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            return entity;
          }
        }
      }
    } catch (e) {
      print("查找封面图失败: $e");
    }
    return null;
  }

  // 计算章节数量
  Future<int> _countChapters(Directory comicDir) async {
    try {
      final chapters = await comicDir.list().where((entity) => entity is Directory).toList();
      return chapters.length;
    } catch (e) {
      print("计算章节数失败: $e");
      return 0;
    }
  }

  // 计算总图片数量
  Future<int> _countTotalImages(Directory comicDir) async {
    int count = 0;
    try {
      await for (var entity in comicDir.list(recursive: true)) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            count++;
          }
        }
      }
    } catch (e) {
      print("计算图片数失败: $e");
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本地漫画'),
        centerTitle: true,
      ),
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
            // 添加直接加载按钮用于调试
            TextButton(
              onPressed: () => _loadComics(),
              child: const Text('忽略权限直接加载（调试用）'),
            ),
          ],
        ),
      );
    }

    if (_comics.isEmpty) {
      return const Center(
        child: Text(
          '未找到任何漫画',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    // 网格布局展示漫画，使用等高等宽设置
    return GridView.builder(
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
        return _buildComicItem(comic);
      },
    );
  }

  Widget _buildComicItem(ComicInfo comic) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComicDetailPage(comicInfo: comic),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 漫画封面
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: comic.coverImage != null
                  ? Image.file(
                      File(comic.coverImage!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                    )
                  : _buildPlaceholder(),
            ),
          ),
          const SizedBox(height: 5),
          // 漫画标题（自动换行）
          Text(
            comic.name,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // 章节数
          Text(
            '${comic.chapterCount} 章',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 封面占位符
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.book, color: Colors.grey, size: 30),
      ),
    );
  }
}

// 漫画信息模型
class ComicInfo {
  final String name;
  final String path;
  final String? coverImage;
  final int chapterCount;
  final int totalImages;

  ComicInfo({
    required this.name,
    required this.path,
    this.coverImage,
    required this.chapterCount,
    required this.totalImages,
  });
}
