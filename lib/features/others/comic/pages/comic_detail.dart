import 'dart:io';
import 'package:flutter/material.dart';
import 'package:torrid/features/others/comic/models/data_class.dart';
import 'package:torrid/features/others/comic/services/io_comic_service.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/comic_header.dart';
import 'package:torrid/features/others/comic/widgets/detail_page/continue_read_btn.dart';
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
        return extractChapterNumber(
          aName,
        ).compareTo(extractChapterNumber(bName));
      });

      List<ChapterInfo> chapters = [];

      for (var dir in chapterDirs) {
        final chapterDir = dir as Directory;
        final chapterName = chapterDir.path.split(Platform.pathSeparator).last;

        // 计算章节图片数量
        final imageCount = await countChapterImages(chapterDir);

        chapters.add(
          ChapterInfo(
            title: chapterName.split('_').isEmpty
                ? ""
                : chapterName.split('_').last,
            name: chapterName,
            path: chapterDir.path,
            imageCount: imageCount,
            chapterNumber: extractChapterNumber(chapterName),
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
            ComicHeader(info: widget.comicInfo,),

            // 阅读选项
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

  // TODO: 之后再用riverpod重构这一块吧.
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
