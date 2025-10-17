import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:torrid/features/essay/models/essay.dart';
import 'package:torrid/features/essay/providers/box_provider.dart';
import 'package:torrid/shared/models/message.dart';
import 'package:torrid/shared/widgets/file_img_builder.dart';

class EssayDetailPage extends ConsumerStatefulWidget {
  final Essay essay;
  
  const EssayDetailPage({
    super.key,
    required this.essay,
  });

  @override
  ConsumerState<EssayDetailPage> createState() => _EssayDetailPageState();
}

class _EssayDetailPageState extends ConsumerState<EssayDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  late Essay _currentEssay;
  
  @override
  void initState() {
    super.initState();
    _currentEssay = widget.essay;
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
  
  void _addMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    final newMessage = Message(
      timestamp: DateTime.now(),
      content: content,
    );
    
    final updatedMessages = List<Message>.from(_currentEssay.messages)
      ..add(newMessage);
    
    final updatedEssay = Essay(
      id: _currentEssay.id,
      date: _currentEssay.date,
      wordCount: _currentEssay.wordCount,
      content: _currentEssay.content,
      imgs: _currentEssay.imgs,
      labels: _currentEssay.labels,
      messages: updatedMessages,
    );
    
    // 保存到 Hive
    final essaysBox = ref.read(essayBoxProvider);
    essaysBox.put(updatedEssay.id, updatedEssay);
    
    setState(() {
      _currentEssay = updatedEssay;
      _messageController.clear();
    });
    
    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('留言已添加')),
    );
  }
  
  void _toggleLabel(String labelId) {
    final updatedLabels = List<String>.from(_currentEssay.labels);
    if (updatedLabels.contains(labelId)) {
      updatedLabels.remove(labelId);
    } else {
      updatedLabels.add(labelId);
    }
    
    final updatedEssay = Essay(
      id: _currentEssay.id,
      date: _currentEssay.date,
      wordCount: _currentEssay.wordCount,
      content: _currentEssay.content,
      imgs: _currentEssay.imgs,
      labels: updatedLabels,
      messages: _currentEssay.messages,
    );
    
    // 保存到 Hive
    final essaysBox = ref.read(essayBoxProvider);
    essaysBox.put(updatedEssay.id, updatedEssay);
    
    setState(() {
      _currentEssay = updatedEssay;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final essay = widget.essay;
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');
    final labelNames = essay.labels;

    return Scaffold(
      appBar: AppBar(
        title: const Text('随笔详情'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期和字数
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(essay.date),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  '${essay.wordCount} 字',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 标签
            if (labelNames.isNotEmpty)
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: labelNames
                    .map((name) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                        ))
                    .toList(),
              ),
            
            const SizedBox(height: 20),
            
            // 内容
            Text(
              essay.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    letterSpacing: 0.3,
                  ),
              textAlign: TextAlign.justify,
            ),
            
            const SizedBox(height: 24),
            
            // 图片
            if (essay.imgs.isNotEmpty)
              Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: essay.imgs.length,
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: FileImageBuilder(relativeImagePath: essay.imgs[index])
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            
            // 留言区标题
            Text(
              '留言',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Divider(height: 24),
            
            // 留言列表
            if (essay.messages.isEmpty)
              Text(
                '暂无留言',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: essay.messages.length,
                itemBuilder: (context, index) {
                  final message = essay.messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MM月dd日 HH:mm').format(message.timestamp),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[500],
                              ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            message.content,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 24),
            
            // 添加留言
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '添加留言...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  onPressed: _addMessage,
                  icon: Icon(
                    Icons.send,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}