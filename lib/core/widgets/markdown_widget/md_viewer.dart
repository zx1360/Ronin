import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'md_style_sheet.dart';

/// Markdown 内容查看器
/// 支持渲染各种 Markdown 元素：标题、列表、代码块、表格、引用等
class MdViewer extends StatelessWidget {
  /// Markdown 文本内容
  final String data;

  /// 是否可选择文本
  final bool selectable;

  /// 是否显示滚动条
  final bool shrinkWrap;

  /// 自定义样式表（可选）
  final MarkdownStyleSheet? styleSheet;

  /// 自定义内边距
  final EdgeInsets? padding;

  /// 链接点击回调（可选，默认使用 url_launcher）
  final void Function(String text, String? href, String title)? onTapLink;

  const MdViewer({
    super.key,
    required this.data,
    this.selectable = true,
    this.shrinkWrap = false,
    this.styleSheet,
    this.padding,
    this.onTapLink,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyleSheet = styleSheet ?? MdStyleSheet.fromContext(context);
    final effectivePadding = padding ?? const EdgeInsets.all(16);

    final markdownWidget = Markdown(
      data: data,
      selectable: selectable,
      shrinkWrap: shrinkWrap,
      padding: effectivePadding,
      styleSheet: effectiveStyleSheet,
      syntaxHighlighter: _CodeSyntaxHighlighter(context),
      onTapLink: onTapLink ?? _defaultOnTapLink,
      imageBuilder: _buildImage,
      checkboxBuilder: _buildCheckbox,
    );

    return markdownWidget;
  }

  /// 默认链接点击处理
  void _defaultOnTapLink(String text, String? href, String title) async {
    if (href == null || href.isEmpty) return;

    final uri = Uri.tryParse(href);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 构建图片组件
  Widget _buildImage(Uri uri, String? title, String? alt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          uri.toString(),
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Text(
                    alt ?? '图片加载失败',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建复选框组件
  Widget _buildCheckbox(bool checked) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Icon(
        checked ? Icons.check_box : Icons.check_box_outline_blank,
        size: 20,
        color: checked ? Colors.blue : Colors.grey,
      ),
    );
  }
}

/// 代码语法高亮器
/// 提供基础的代码语法高亮效果
class _CodeSyntaxHighlighter extends SyntaxHighlighter {
  final BuildContext context;

  _CodeSyntaxHighlighter(this.context);

  @override
  TextSpan format(String source) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 基础颜色配置
    final textColor = isDark ? Colors.grey[300]! : Colors.grey[800]!;
    final keywordColor = isDark ? Colors.purple[300]! : Colors.purple[700]!;
    final stringColor = isDark ? Colors.green[300]! : Colors.green[700]!;
    final commentColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
    final numberColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;

    // 关键字列表（包含多语言常见关键字）
    const keywords = {
      // Dart 关键字
      'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
      'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
      'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
      'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
      'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
      'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
      'return', 'sealed', 'set', 'show', 'static', 'super', 'switch', 'sync',
      'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
      'with', 'yield',
      // 常见类型
      'int',
      'double',
      'String',
      'bool',
      'List',
      'Map',
      'Set',
      'Future',
      'Stream',
      // JavaScript/TypeScript 常见关键字（去除与 Dart 重复的）
      'let', 'function', 'typeof', 'instanceof', 'undefined',
      // Python 常见关键字（去除与 Dart 重复的）
      'def', 'lambda', 'from', 'pass', 'raise', 'global', 'nonlocal',
      'and', 'or', 'not', 'True', 'False', 'None', 'elif', 'except',
    };

    final spans = <TextSpan>[];
    final buffer = StringBuffer();
    var inString = false;
    var stringChar = '';
    var inComment = false;
    var inLineComment = false;

    void addBufferAsText() {
      if (buffer.isNotEmpty) {
        final text = buffer.toString();
        // 检查是否为关键字
        if (keywords.contains(text)) {
          spans.add(
            TextSpan(
              text: text,
              style: TextStyle(
                color: keywordColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
        // 检查是否为数字
        else if (RegExp(r'^-?\d+\.?\d*$').hasMatch(text)) {
          spans.add(
            TextSpan(
              text: text,
              style: TextStyle(color: numberColor),
            ),
          );
        } else {
          spans.add(
            TextSpan(
              text: text,
              style: TextStyle(color: textColor),
            ),
          );
        }
        buffer.clear();
      }
    }

    for (var i = 0; i < source.length; i++) {
      final char = source[i];
      final nextChar = i + 1 < source.length ? source[i + 1] : '';

      // 处理换行（重置行注释）
      if (char == '\n') {
        if (inLineComment) {
          spans.add(
            TextSpan(
              text: buffer.toString(),
              style: TextStyle(
                color: commentColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
          buffer.clear();
          inLineComment = false;
          inComment = false;
        } else {
          addBufferAsText();
        }
        spans.add(
          TextSpan(
            text: char,
            style: TextStyle(color: textColor),
          ),
        );
        continue;
      }

      // 处理行注释
      if (!inString && !inComment && char == '/' && nextChar == '/') {
        addBufferAsText();
        inLineComment = true;
        inComment = true;
        buffer.write(char);
        continue;
      }

      // 处理注释
      if (inComment) {
        buffer.write(char);
        continue;
      }

      // 处理字符串
      if (!inString && (char == '"' || char == "'" || char == '`')) {
        addBufferAsText();
        inString = true;
        stringChar = char;
        buffer.write(char);
        continue;
      }

      if (inString) {
        buffer.write(char);
        if (char == stringChar && (i == 0 || source[i - 1] != '\\')) {
          spans.add(
            TextSpan(
              text: buffer.toString(),
              style: TextStyle(color: stringColor),
            ),
          );
          buffer.clear();
          inString = false;
        }
        continue;
      }

      // 处理普通字符
      if (RegExp(r'[\w_]').hasMatch(char)) {
        buffer.write(char);
      } else {
        addBufferAsText();
        spans.add(
          TextSpan(
            text: char,
            style: TextStyle(color: textColor),
          ),
        );
      }
    }

    // 处理剩余内容
    if (buffer.isNotEmpty) {
      if (inString) {
        spans.add(
          TextSpan(
            text: buffer.toString(),
            style: TextStyle(color: stringColor),
          ),
        );
      } else if (inComment) {
        spans.add(
          TextSpan(
            text: buffer.toString(),
            style: TextStyle(color: commentColor, fontStyle: FontStyle.italic),
          ),
        );
      } else {
        addBufferAsText();
      }
    }

    return TextSpan(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.5,
      ),
      children: spans,
    );
  }
}

/// 带复制按钮的代码块包装器
/// 可以通过 MarkdownBody 的 builders 参数使用
class CodeBlockWrapper extends StatefulWidget {
  final Widget child;
  final String code;

  const CodeBlockWrapper({super.key, required this.child, required this.code});

  @override
  State<CodeBlockWrapper> createState() => _CodeBlockWrapperState();
}

class _CodeBlockWrapperState extends State<CodeBlockWrapper> {
  bool _copied = false;

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              size: 18,
              color: _copied ? Colors.green : Colors.grey,
            ),
            onPressed: _copyCode,
            tooltip: _copied ? '已复制' : '复制代码',
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }
}
