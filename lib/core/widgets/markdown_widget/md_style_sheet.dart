import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Typora 风格的 Markdown 样式表
/// 提供简洁、美观的 Markdown 渲染样式
class MdStyleSheet {
  MdStyleSheet._();

  /// 创建类 Typora 风格的样式表
  static MarkdownStyleSheet fromContext(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 基础颜色配置
    final textColor = isDark ? Colors.grey[200]! : Colors.grey[850]!;
    final codeBackgroundColor = isDark
        ? Colors.grey[900]!
        : const Color(0xFFF6F8FA);
    final blockquoteBorderColor = isDark
        ? Colors.grey[600]!
        : Colors.grey[400]!;
    final tableBorderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    final linkColor = isDark ? Colors.blue[300]! : Colors.blue[700]!;

    return MarkdownStyleSheet(
      // 段落样式
      p: TextStyle(
        color: textColor,
        fontSize: 16,
        height: 1.7,
        letterSpacing: 0.2,
      ),
      pPadding: const EdgeInsets.only(bottom: 12),

      // 标题样式 (H1-H6)
      h1: TextStyle(
        color: textColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h1Padding: const EdgeInsets.only(top: 24, bottom: 16),
      h2: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2Padding: const EdgeInsets.only(top: 20, bottom: 12),
      h3: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h3Padding: const EdgeInsets.only(top: 16, bottom: 10),
      h4: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h4Padding: const EdgeInsets.only(top: 12, bottom: 8),
      h5: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h5Padding: const EdgeInsets.only(top: 10, bottom: 6),
      h6: TextStyle(
        color: textColor.withValues(alpha: 0.8),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h6Padding: const EdgeInsets.only(top: 8, bottom: 4),

      // 链接样式
      a: TextStyle(color: linkColor, decoration: TextDecoration.none),

      // 强调样式
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      del: TextStyle(
        color: textColor.withValues(alpha: 0.6),
        decoration: TextDecoration.lineThrough,
      ),

      // 行内代码样式
      code: TextStyle(
        backgroundColor: codeBackgroundColor,
        color: isDark ? Colors.pink[300]! : const Color(0xFFD63384),
        fontFamily: 'monospace',
        fontSize: 14,
      ),

      // 代码块样式
      codeblockDecoration: BoxDecoration(
        color: codeBackgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),

      // 引用块样式
      blockquote: TextStyle(
        color: textColor.withValues(alpha: 0.8),
        fontStyle: FontStyle.italic,
        fontSize: 15,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: blockquoteBorderColor, width: 4),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),

      // 列表样式
      listBullet: TextStyle(color: textColor, fontSize: 16),
      listIndent: 24,
      listBulletPadding: const EdgeInsets.only(right: 8),

      // 表格样式
      tableHead: TextStyle(
        color: textColor,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      tableBody: TextStyle(color: textColor, fontSize: 14),
      tableBorder: TableBorder.all(color: tableBorderColor, width: 1),
      tableHeadAlign: TextAlign.center,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),

      // 水平分割线样式
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: tableBorderColor, width: 1)),
      ),

      // 图片样式
      img: TextStyle(color: textColor),

      // 复选框样式
      checkbox: TextStyle(color: linkColor, fontSize: 16),
    );
  }
}
