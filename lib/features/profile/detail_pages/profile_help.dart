import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

class ProfileHelp extends StatefulWidget {
  const ProfileHelp({super.key});

  @override
  State<ProfileHelp> createState() => _ProfileHelpState();
}

class _ProfileHelpState extends State<ProfileHelp> {
  // 存储从本地文件读取的Markdown内容
  String? markdownContent;
  // 加载状态标识
  bool isLoading = true;
  // 错误信息
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // 初始化时读取本地Markdown文件
    _loadMarkdownFile();
  }

  // 读取本地Markdown文件
  Future<void> _loadMarkdownFile() async {
    try {
      // 从assets加载文件内容
      String content = await rootBundle.loadString('assets/files/help.md');

      setState(() {
        markdownContent = content;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = '无法加载帮助内容: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody());
  }

  // 根据不同状态构建页面内容
  Widget _buildBody() {
    if (isLoading) {
      // 加载中状态
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      // 加载错误状态
      return Center(
        child: Text(
          errorMessage!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 成功加载后渲染Markdown内容
    return Markdown(
      data: markdownContent!,
      syntaxHighlighter: CodeSyntaxHighlighter(),
      // imageBuilder: (uri, title, alt) {
      //   return Image.network(
      //     uri.toString(),
      //     fit: BoxFit.cover,
      //     errorBuilder: (context, error, stackTrace) {
      //       return Text(alt ?? '图片加载失败');
      //     },
      //   );
      // },
    );
  }
}

// 代码语法高亮器
class CodeSyntaxHighlighter extends SyntaxHighlighter {
  CodeSyntaxHighlighter();

  @override
  TextSpan format(String source) {
    // 这里可以实现自定义代码高亮逻辑
    // 简单实现：返回灰色等宽字体
    return TextSpan(
      style: const TextStyle(
        color: Color(0xFF666666),
        fontFamily: 'monospace',
        fontSize: 14,
      ),
      text: source,
    );
  }
}
