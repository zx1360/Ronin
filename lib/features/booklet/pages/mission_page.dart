import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/booklet/widgets/mission/mission_widget.dart';

class MissionPage extends StatefulWidget {
  const MissionPage({super.key});

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  // final List<MissionWidget> missions = ...;
  final timeFormat = DateFormat('yyyy-MM-dd HH:mm');
  final dateFormat = DateFormat('yyyy-MM-dd');

  // 消息详情底部弹窗 - 增强版
  Widget _buildMessageBottomSheet(BuildContext context, MissionWidget mission) {
    // 获取状态信息   诶哟这个写法
    final Map<String, dynamic> statusInfo = [
      {'color': Colors.yellow.shade600, 'text': '进行中'},
      {'color': Colors.green.shade600, 'text': '已完成'},
      {'color': Colors.grey.shade600, 'text': '已终止'},
    ][mission.status];

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                mission.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow.shade800,
                ),
              ),
              Text(
                statusInfo['text'],
                style: TextStyle(
                  color: statusInfo['color'],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const Divider(height: 24, color: Colors.grey),

          // 大图展示
          if (mission.img != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                mission.img!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.yellow.shade100,
                  child: Icon(Icons.image_not_supported, color: Colors.yellow.shade400, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 任务描述
          Text(
            mission.description,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 日期信息
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey.shade500, size: 16),
                  const SizedBox(width: 8),
                  Text('开始: ${dateFormat.format(mission.startDate)}', style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    mission.status == 0 ? Icons.event : Icons.event_available,
                    color: statusInfo['color'],
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mission.status == 0
                        ? mission.deadline != null ? '截止: ${dateFormat.format(mission.deadline!)}' : '无截止日期'
                        : '${mission.status == 1 ? '完成于' : '终止于'}: ${dateFormat.format(mission.terminateDate!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: statusInfo['color'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24, color: Colors.grey),
          
          // 记录标题
          const Text(
            '任务记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 12),

          // 消息列表
          if (mission.messages.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('暂无记录', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            )
          ] else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: mission.messages.map((msg) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeFormat.format(msg.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            msg.content,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("挑战页..."),
      ),
      // body: ListView.builder(
      //   padding: const EdgeInsets.symmetric(vertical: 12),
      //   itemCount: missions.length,
      //   itemBuilder: (context, index) {
      //     MissionWidget mission = missions[index];
      //     return GestureDetector(
      //       onDoubleTap: () => showModalBottomSheet(
      //         context: context,
      //         backgroundColor: Colors.transparent,
      //         isScrollControlled: true,
      //         builder: (context) => _buildMessageBottomSheet(context, mission)
      //       ),
      //       child: mission,
      //     );
      //   },
      // ),
      // backgroundColor: Colors.yellow.shade50,
    );
  }
}
    