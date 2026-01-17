import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'md_viewer.dart';

/// 本地 Assets Markdown 内容构建器
/// 从本地 assets 文件加载 Markdown 内容并渲染
class AssetsMdBuilder extends StatefulWidget {
  /// Assets 中 Markdown 文件的路径
  final String mdPath;

  /// 是否显示 AppBar
  final bool showAppBar;

  /// AppBar 标题
  final String? title;

  const AssetsMdBuilder({
    super.key,
    required this.mdPath,
    this.showAppBar = false,
    this.title,
  });

  @override
  State<AssetsMdBuilder> createState() => _AssetsMdBuilderState();
}

class _AssetsMdBuilderState extends State<AssetsMdBuilder> {
  /// 加载的 Markdown 内容
  String? _content;

  /// 加载状态
  bool _isLoading = true;

  /// 错误信息
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMarkdownFile();
  }

  @override
  void didUpdateWidget(covariant AssetsMdBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 路径变化时重新加载
    if (oldWidget.mdPath != widget.mdPath) {
      _loadMarkdownFile();
    }
  }

  /// 从 assets 加载 Markdown 文件
  Future<void> _loadMarkdownFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final content = await rootBundle.loadString(widget.mdPath);
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '无法加载内容：${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      body = MdViewer(data: _content!);
    }

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title ?? '')),
        body: body,
      );
    }

    return body;
  }
}
