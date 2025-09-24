import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:torrid/models/common/message.dart';
import 'package:torrid/models/tuntun/info.dart';
import 'package:torrid/models/tuntun/status.dart';

class TuntunPage extends StatefulWidget {
  const TuntunPage({super.key});

  @override
  State<TuntunPage> createState() => _TuntunPageState();
}

class _TuntunPageState extends State<TuntunPage> {
  late Box<Info> _infoBox;
  late Box<Status> _statusBox;
  List<Info> _allMedia = [];
  List<Info> _filteredMedia = [];
  final List<String> _selectedMediaIds = [];
  String? _currentFilterTag;
  bool _showDeleted = false;

  @override
  void initState() {
    super.initState();
    _initHiveBoxes();
  }

  Future<void> _initHiveBoxes() async {
    _infoBox = Hive.box<Info>('mediaInfo');
    _statusBox = Hive.box<Status>('mediaStatus');
    _loadAndSortMedia();
    
    // 监听数据变化
    _infoBox.listenable().addListener(_loadAndSortMedia);
    _statusBox.listenable().addListener(_loadAndSortMedia);
  }

  void _loadAndSortMedia() {
    // 获取所有媒体
    final mediaList = _infoBox.values.toList();
    
    // 按创建时间和修改时间中较早的一个升序排序
    mediaList.sort((a, b) {
      final aTime = a.createTime < a.modifyTime ? a.createTime : a.modifyTime;
      final bTime = b.createTime < b.modifyTime ? b.createTime : b.modifyTime;
      return aTime.compareTo(bTime);
    });
    
    // 应用过滤
    setState(() {
      _allMedia = mediaList;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredMedia = _allMedia.where((media) {
      final status = _getStatusForMedia(media.id);
      
      // 过滤已标记删除的项目（如果不显示）
      if (!_showDeleted && status.isMarkedDeleted) {
        return false;
      }
      
      // 过滤标签（如果有选择）
      if (_currentFilterTag != null && 
          _currentFilterTag!.isNotEmpty && 
          !status.tags.contains(_currentFilterTag)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Status _getStatusForMedia(String mediaId) {
    return _statusBox.get(mediaId) ?? Status(mediaId: mediaId);
  }

  void _toggleMediaSelection(String mediaId) {
    setState(() {
      if (_selectedMediaIds.contains(mediaId)) {
        _selectedMediaIds.remove(mediaId);
      } else {
        _selectedMediaIds.add(mediaId);
      }
    });
  }

  void _createBundle() {
    if (_selectedMediaIds.length < 2) {
      _showSnackBar('请至少选择两个媒体文件来创建合集');
      return;
    }

    // 为每个选中的媒体添加合集关系
    for (final mediaId in _selectedMediaIds) {
      final status = _getStatusForMedia(mediaId);
      final newBundle = List<String>.from(status.bundleWith);
      
      for (final otherId in _selectedMediaIds) {
        if (otherId != mediaId && !newBundle.contains(otherId)) {
          newBundle.add(otherId);
        }
      }
      
      _statusBox.put(mediaId, status.copyWith(bundleWith: newBundle));
    }

    setState(() {
      _selectedMediaIds.clear();
    });
    _showSnackBar('已创建合集');
  }

  void _toggleDeleteStatus(String mediaId) {
    final status = _getStatusForMedia(mediaId);
    _statusBox.put(mediaId, status.copyWith(
      isMarkedDeleted: !status.isMarkedDeleted
    ));
    _showSnackBar(status.isMarkedDeleted ? '已取消删除标记' : '已标记为删除');
  }

  void _addTag(String mediaId, String tag) {
    if (tag.isEmpty) return;
    
    final status = _getStatusForMedia(mediaId);
    final newTags = List<String>.from(status.tags);
    
    if (!newTags.contains(tag)) {
      newTags.add(tag);
      _statusBox.put(mediaId, status.copyWith(tags: newTags));
      _showSnackBar('已添加标签: $tag');
    }
  }

  void _removeTag(String mediaId, String tag) {
    final status = _getStatusForMedia(mediaId);
    final newTags = List<String>.from(status.tags)..remove(tag);
    _statusBox.put(mediaId, status.copyWith(tags: newTags));
    _showSnackBar('已移除标签: $tag');
  }

  void _addMessage(String mediaId, String content) {
    if (content.isEmpty) return;
    
    final status = _getStatusForMedia(mediaId);
    final newMessages = List<Message>.from(status.messages)
      ..add(Message(timestamp: DateTime.now(), content: content));
    
    _statusBox.put(mediaId, status.copyWith(messages: newMessages));
    _showSnackBar('已添加留言');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showAddTagDialog(String mediaId) {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(hintText: '输入标签'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _addTag(mediaId, textController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddMessageDialog(String mediaId) {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加留言'),
        content: TextField(
          controller: textController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '输入留言内容'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              _addMessage(mediaId, textController.text.trim());
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showMediaDetails(Info media) {
    final status = _getStatusForMedia(media.id);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '文件详情',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // 文件信息
              _buildDetailRow('文件名', media.filePath.split('/').last),
              _buildDetailRow('类型', '${media.ext.toUpperCase()} (${media.mimeType})'),
              _buildDetailRow('大小', '${(media.fileSize / 1024).toStringAsFixed(1)} KB'),
              _buildDetailRow('创建时间', DateFormat('yyyy-MM-dd HH:mm').format(
                DateTime.fromMillisecondsSinceEpoch(media.createTime)
              )),
              _buildDetailRow('修改时间', DateFormat('yyyy-MM-dd HH:mm').format(
                DateTime.fromMillisecondsSinceEpoch(media.modifyTime)
              )),
              
              const SizedBox(height: 24),
              
              // 标签
              Text(
                '标签',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: status.tags.map((tag) => Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(media.id, tag),
                )).toList(),
              ),
              TextButton(
                onPressed: () => _showAddTagDialog(media.id),
                child: const Text('+ 添加标签'),
              ),
              
              const SizedBox(height: 24),
              
              // 留言
              Text(
                '留言',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (status.messages.isEmpty)
                const Text('暂无留言')
              else
                ...status.messages.map((msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(msg.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(msg.content),
                    ],
                  ),
                )),
              TextButton(
                onPressed: () => _showAddMessageDialog(media.id),
                child: const Text('+ 添加留言'),
              ),
              
              const SizedBox(height: 24),
              
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _toggleDeleteStatus(media.id);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status.isMarkedDeleted ? Colors.green : Colors.red,
                    ),
                    child: Text(status.isMarkedDeleted ? '取消删除' : '标记删除'),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体管理'),
        actions: [
          // 过滤选项
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'all') {
                  _currentFilterTag = null;
                } else if (value == 'deleted') {
                  _showDeleted = !_showDeleted;
                } else {
                  _currentFilterTag = value;
                }
              });
              _applyFilters();
            },
            itemBuilder: (context) {
              // 获取所有唯一标签
              final allTags = <String>{};
              for (final media in _allMedia) {
                final status = _getStatusForMedia(media.id);
                allTags.addAll(status.tags);
              }
              
              return [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('全部标签'),
                ),
                PopupMenuItem(
                  value: 'deleted',
                  child: Text(_showDeleted ? '隐藏已删除' : '显示已删除'),
                ),
                if (allTags.isNotEmpty)
                  const PopupMenuDivider(),
                ...allTags.map((tag) => PopupMenuItem(
                  value: tag,
                  child: Text(tag),
                )),
              ];
            },
          ),
        ],
      ),
      
      body: _filteredMedia.isEmpty
          ? const Center(child: Text('没有找到媒体文件'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _filteredMedia.length,
              itemBuilder: (context, index) {
                final media = _filteredMedia[index];
                final status = _getStatusForMedia(media.id);
                final isSelected = _selectedMediaIds.contains(media.id);
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleMediaSelection(media.id),
                    ),
                    title: Text(
                      media.filePath.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration: status.isMarkedDeleted 
                            ? TextDecoration.lineThrough 
                            : null,
                        color: status.isMarkedDeleted 
                            ? Colors.grey 
                            : null,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${media.ext.toUpperCase()} • ${(media.fileSize / 1024).toStringAsFixed(1)} KB'),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: status.tags.take(3).map((tag) => 
                            Chip(
                              label: Text(
                                tag,
                                style: const TextStyle(fontSize: 12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            )
                          ).toList(),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      media.mimeType.startsWith('image/') 
                          ? Icons.image 
                          : media.mimeType.startsWith('video/')
                              ? Icons.video_library
                              : Icons.insert_drive_file,
                      color: Theme.of(context).primaryColor,
                    ),
                    onTap: () => _showMediaDetails(media),
                  ),
                );
              },
            ),
      
      // 批量操作按钮
      floatingActionButton: _selectedMediaIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createBundle,
              child: const Icon(Icons.collections),
            )
          : null,
    );
  }

  @override
  void dispose() {
    // 移除监听器
    _infoBox.listenable().removeListener(_loadAndSortMedia);
    _statusBox.listenable().removeListener(_loadAndSortMedia);
    super.dispose();
  }
}
