import 'dart:io';
import 'package:flutter/material.dart';
import 'package:torrid/core/services/debug/logging_service.dart';
import 'package:torrid/features/others/comic/pages/comic_page.dart';
import 'package:torrid/features/others/comic/widgets/continue_read_btn.dart';
import 'comic_read_flip.dart';
import 'comic_read_scroll.dart';

class ComicDetailPage extends StatefulWidget {
  final ComicInfo comicInfo;

  const ComicDetailPage({super.key, required this.comicInfo});

  @override
  State<ComicDetailPage> createState() => _ComicDetailPageState();
}

class _ComicDetailPageState extends State<ComicDetailPage> {
  List<ChapterInfo> _chapters = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isScrollMode = false;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    try {
      final comicDir = Directory(widget.comicInfo.path);

      // 列出所有章节文件夹并排序
      final chapterDirs = await comicDir
          .list()
          .where((entity) => entity is Directory)
          .toList();

      // 按章节序号排序
      chapterDirs.sort((a, b) {
        final aName = (a as Directory).path.split(Platform.pathSeparator).last;
        final bName = (b as Directory).path.split(Platform.pathSeparator).last;
        return _extractChapterNumber(
          aName,
        ).compareTo(_extractChapterNumber(bName));
      });

      List<ChapterInfo> chapters = [];

      for (var dir in chapterDirs) {
        final chapterDir = dir as Directory;
        final chapterName = chapterDir.path.split(Platform.pathSeparator).last;

        // 计算章节图片数量
        final imageCount = await _countChapterImages(chapterDir);

        chapters.add(
          ChapterInfo(
            title: chapterName.split('_').isEmpty
                ? ""
                : chapterName.split('_').last,
            name: chapterName,
            path: chapterDir.path,
            imageCount: imageCount,
            chapterNumber: _extractChapterNumber(chapterName),
          ),
        );
      }

      setState(() {
        _chapters = chapters;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "加载章节失败: ${e.toString()}";
      });
    }
  }

  // 从章节名称中提取章节号
  int _extractChapterNumber(String chapterName) {
    // 确保章节名格式为 "数字_章节名"
    final parts = chapterName.split('_');
    if (parts.isNotEmpty) {
      return int.tryParse(parts[0]) ?? 0;
    }
    return 0;
  }

  // 计算章节图片数量
  Future<int> _countChapterImages(Directory chapterDir) async {
    int count = 0;
    try {
      await for (var entity in chapterDir.list()) {
        if (entity is File) {
          final extension = entity.path.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
            count++;
          }
        }
      }
    } catch (e) {
      AppLogger().error("计算章节图片数失败: $e");
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.comicInfo.name, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 漫画封面和基本信息
            _buildComicHeader(),

            // 章节列表标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ContinueReadingButton(
                    comicName: widget.comicInfo.name,
                    chapters: _chapters,
                  ),
                  Row(
                    children: [
                      const Text(
                        '章节列表',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      Text(_isScrollMode ? "下拉阅读" : "翻页阅读"),
                      Switch(
                        value: _isScrollMode,
                        onChanged: (bool value) {
                          setState(() {
                            _isScrollMode = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 章节列表
            _buildChaptersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComicHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.comicInfo.coverImage != null
                ? Image.file(
                    File(widget.comicInfo.coverImage!),
                    width: 120,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 120,
                    height: 180,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.book, color: Colors.grey, size: 40),
                    ),
                  ),
          ),

          const SizedBox(width: 16),

          // 漫画信息，使用Expanded避免溢出
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.comicInfo.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                _buildInfoRow('章节数', '${widget.comicInfo.chapterCount} 章'),
                _buildInfoRow('总图片数', '${widget.comicInfo.totalImages} 张'),
                _buildInfoRow(
                  '存储路径',
                  widget.comicInfo.path.split(Platform.pathSeparator).last,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(20), child: Text('未找到任何章节')),
      );
    }

    // 使用GridView实现等高等宽的章节按钮
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5, // 适当调整比例使按钮等高等宽且美观
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        return _buildChapterItem(chapter);
      },
    );
  }

  Widget _buildChapterItem(ChapterInfo chapter) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[100],
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      // 根据切换按钮的状态, 选择翻页阅读页面或下拉阅读页面.
      onPressed: () {
        if (_isScrollMode) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComicScrollPage(
                comicName: widget.comicInfo.name,
                chapters: _chapters,
                currentChapter: chapter.chapterNumber - 1,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ComicReadPage(
                comicName: widget.comicInfo.name,
                chapters: _chapters,
                currentChapter: chapter.chapterNumber - 1,
              ),
            ),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            chapter.title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '第 ${chapter.chapterNumber} 章',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 8),
              Text(
                '${chapter.imageCount} 页',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 章节信息模型
class ChapterInfo {
  // 章节标题
  final String title;
  // 章节文件夹名
  final String name;
  // 章节路径
  final String path;
  final int imageCount;
  final int chapterNumber;

  ChapterInfo({
    this.title = "",
    required this.name,
    required this.path,
    required this.imageCount,
    required this.chapterNumber,
  });
}
