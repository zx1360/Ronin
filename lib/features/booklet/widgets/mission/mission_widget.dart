import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/shared/models/message.dart';

class MissionWidget extends StatelessWidget {
  const MissionWidget({
    super.key,
    required this.title,
    required this.description,
    this.img,
    this.messages = const [],
    required this.status,
    required this.setState,
    required this.startDate,
    this.terminateDate,
    this.deadline,
  });
  final String title;
  final String description;
  final String? img;
  final List<Message> messages;
  final int status;
  final Function setState;
  final DateTime startDate;
  final DateTime? terminateDate;
  final DateTime? deadline;

  // 根据任务状态返回对应的颜色和文本
  Map<String, dynamic> _getStatusInfo() {
    switch (status) {
      case 0:
        return {
          'color': Colors.yellow.shade600,
          'text': '进行中',
          'icon': Icons.play_circle,
        };
      case 1:
        return {
          'color': Colors.green.shade600,
          'text': '已完成',
          'icon': Icons.check_circle,
        };
      case 2:
        return {
          'color': Colors.grey.shade600,
          'text': '已终止',
          'icon': Icons.cancel,
        };
      default:
        return{};
    }
  }

  // 计算任务到设定期限的进度百分比(如果设定了期限)
  double _getProgressPercentage() {
    // 只有进行中的任务且设置了截止日期才计算进度
    if (status == 0 && deadline != null) {
      final totalDuration = deadline!.difference(startDate).inDays;
      final elapsedDuration = DateTime.now().difference(startDate).inDays;

      if (totalDuration <= 0) return 0.0;
      return (elapsedDuration / totalDuration).clamp(0.0, 1.0);
    }
    return 0.0; // 非进行中或无截止日期不显示进度
  }

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo();
    final progress = _getProgressPercentage();
    // 初始化DateFormat
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.shade200.withValues(alpha: .3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow.shade800,
                ),
              ),
              Row(
                children: [
                  Icon(
                    statusInfo['icon'],
                    color: statusInfo['color'],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    statusInfo['text'],
                    style: TextStyle(
                      color: statusInfo['color'],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 任务图片
          if (img != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                img!,
                width: double.infinity,
                height: 180, // 增大图片高度，实现大图展示
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    color: Colors.yellow.shade100,
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.yellow.shade400,
                      size: 40,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),

          // 任务描述
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // 两端对齐
            children: [
              // 起始日期
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey.shade500, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '开始: ${dateFormat.format(startDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // 状态相关日期（截止/完成/终止）
              Row(
                children: [
                  Icon(
                    status == 0
                        ? Icons.event
                        : Icons.event_available,
                    color: status == 0
                        ? Colors.yellow.shade600
                        : (status == 1
                            ? Colors.green.shade600
                            : Colors.grey.shade600),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status == 0
                        ? deadline != null
                            ? '截止: ${dateFormat.format(deadline!)}'
                            : '无截止'
                        : '${status == 0 ? '完成' : '终止'}: ${dateFormat.format(terminateDate!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: status == 0
                          ? Colors.grey.shade600
                          : (status == 1
                              ? Colors.green.shade600
                              : Colors.grey.shade600),
                      fontWeight: status != 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 进度条
          if (status == 0 && deadline != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '完成进度: ${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.yellow.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.yellow.shade600,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          ],

          // 消息数量提示
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.comment, color: Colors.yellow.shade600, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${messages.length} 条记录 (双击查看详情)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
