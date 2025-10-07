// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:intl/intl.dart';
// import 'package:torrid/features/essay/models/essay.dart';
// import 'package:torrid/features/essay/providers/essay_provider.dart';
// import 'package:torrid/features/essay/widgets/image_grid.dart';
// import 'package:torrid/features/essay/widgets/label_chip.dart';
// import 'package:torrid/shared/models/message.dart';

// class EssayDetailPage extends ConsumerStatefulWidget {
//   final Essay essay;
  
//   const EssayDetailPage({
//     super.key,
//     required this.essay,
//   });

//   @override
//   ConsumerState<EssayDetailPage> createState() => _EssayDetailPageState();
// }

// class _EssayDetailPageState extends ConsumerState<EssayDetailPage> {
//   final TextEditingController _messageController = TextEditingController();
//   late Essay _currentEssay;
  
//   @override
//   void initState() {
//     super.initState();
//     _currentEssay = widget.essay;
//   }
  
//   @override
//   void dispose() {
//     _messageController.dispose();
//     super.dispose();
//   }
  
//   void _addMessage() {
//     final content = _messageController.text.trim();
//     if (content.isEmpty) return;
    
//     final newMessage = Message(
//       timestamp: DateTime.now(),
//       content: content,
//     );
    
//     final updatedMessages = List<Message>.from(_currentEssay.messages)
//       ..add(newMessage);
    
//     final updatedEssay = Essay(
//       id: _currentEssay.id,
//       date: _currentEssay.date,
//       wordCount: _currentEssay.wordCount,
//       content: _currentEssay.content,
//       imgs: _currentEssay.imgs,
//       labels: _currentEssay.labels,
//       messages: updatedMessages,
//     );
    
//     // 保存到 Hive
//     final essaysBox = ref.read(essaysBoxProvider);
//     essaysBox.put(updatedEssay.id, updatedEssay);
    
//     setState(() {
//       _currentEssay = updatedEssay;
//       _messageController.clear();
//     });
    
//     // 显示成功提示
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('留言已添加')),
//     );
//   }
  
//   void _toggleLabel(String labelId) {
//     final updatedLabels = List<String>.from(_currentEssay.labels);
//     if (updatedLabels.contains(labelId)) {
//       updatedLabels.remove(labelId);
//     } else {
//       updatedLabels.add(labelId);
//     }
    
//     final updatedEssay = Essay(
//       id: _currentEssay.id,
//       date: _currentEssay.date,
//       wordCount: _currentEssay.wordCount,
//       content: _currentEssay.content,
//       imgs: _currentEssay.imgs,
//       labels: updatedLabels,
//       messages: _currentEssay.messages,
//     );
    
//     // 保存到 Hive
//     final essaysBox = ref.read(essaysBoxProvider);
//     essaysBox.put(updatedEssay.id, updatedEssay);
    
//     setState(() {
//       _currentEssay = updatedEssay;
//     });
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     final labelsAsync = ref.watch(labelsProvider);
    
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('随笔详情'),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // 日期
//             Text(
//               DateFormat('yyyy年MM月dd日 HH:mm').format(_currentEssay.date),
//               style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                 color: Colors.grey,
//               ),
//             ),
            
//             const SizedBox(height: 16),
            
//             // 内容
//             Text(
//               _currentEssay.content,
//               style: Theme.of(context).textTheme.bodyLarge,
//               textAlign: TextAlign.justify,
//             ),
            
//             const SizedBox(height: 16),
            
//             // 图片
//             if (_currentEssay.imgs.isNotEmpty)
//               ImageGrid(images: _currentEssay.imgs),
            
//             const SizedBox(height: 16),
            
//             // 标签
//             const Text(
//               '标签:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
//             labelsAsync.when(
//               loading: () => const CircularProgressIndicator(),
//               error: (error, stack) => Text('加载标签失败: $error'),
//               data: (labels) {
//                 return Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: labels.map((label) {
//                     final isSelected = _currentEssay.labels.contains(label.id);
//                     return LabelChip(
//                       label: label,
//                       isSelected: isSelected,
//                       onTap: () => _toggleLabel(label.id),
//                     );
//                   }).toList(),
//                 );
//               },
//             ),
            
//             const SizedBox(height: 24),
            
//             // 留言区
//             const Text(
//               '留言:',
//               style: TextStyle(fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 8),
            
//             // 留言列表
//             if (_currentEssay.messages.isEmpty)
//               const Text('暂无留言')
//             else
//               Column(
//                 children: _currentEssay.messages.map((message) {
//                   return ListTile(
//                     leading: const Icon(Icons.message),
//                     title: Text(message.content),
//                     subtitle: Text(
//                       DateFormat('yyyy-MM-dd HH:mm').format(message.timestamp),
//                     ),
//                   );
//                 }).toList(),
//               ),
            
//             const SizedBox(height: 16),
            
//             // 添加留言
//             Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: const InputDecoration(
//                       hintText: '添加留言...',
//                       border: OutlineInputBorder(),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: _addMessage,
//                   child: const Text('发送'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }