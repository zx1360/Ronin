// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:torrid/app/theme_light.dart';
// import 'package:torrid/features/essay/models/essay.dart';
// import 'package:torrid/features/essay/models/label.dart';
// import 'package:torrid/features/essay/providers/notifier_provider.dart';
// import 'package:torrid/features/essay/providers/status_provider.dart';
// import 'package:torrid/features/essay/widgets/detail/essay_content_widget.dart';
// import 'package:torrid/features/essay/widgets/modify/retag_widget.dart';
// import 'package:torrid/shared/models/message.dart';

// class EssayDetailPage extends ConsumerStatefulWidget {
//   final Essay essay;

//   const EssayDetailPage({super.key, required this.essay});

//   @override
//   ConsumerState<EssayDetailPage> createState() => _EssayDetailPageState();
// }

// class _EssayDetailPageState extends ConsumerState<EssayDetailPage> {
//   final TextEditingController _messageController = TextEditingController();
//   final FocusNode _focusNode = FocusNode();
//   late final Essay _currentEssay = widget.essay;

//   @override
//   void initState() {
//     super.initState();
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _focusNode.dispose();
//     super.dispose();
//   }

//   // 添加留言
//   void _addMessage() {
//     final content = _messageController.text.trim();
//     _messageController.clear();
//     _focusNode.unfocus();
//     if (content.isEmpty) return;

//     ref
//         .watch(essayServerProvider.notifier)
//         .appendMessage(
//           _currentEssay.id,
//           Message(timestamp: DateTime.now(), content: content),
//         );

//     setState(() {});
//   }

//   // 更改标签.
//   void _retag(Label label) async{
//     await ref.watch(essayServerProvider.notifier).retag(_currentEssay.id, label);
//   }

//   @override
//   Widget build(BuildContext context) {
//     ref.watch(essaysProvider);

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: AppTheme.surfaceContainer,
//         foregroundColor: AppTheme.onSurface,
//         elevation: 1,
//         titleTextStyle: Theme.of(
//           context,
//         ).appBarTheme.titleTextStyle?.copyWith(color: AppTheme.onSurface),
//         centerTitle: true,
//         // 底部分割线
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Divider(color: AppTheme.outline.withOpacity(0.3), height: 1),
//         ),
//         title: const Text('随笔详情'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: () => _showModify(context, ref),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             EssayContentWidget(essay: _currentEssay),

//             const SizedBox(height: 24),

//             // 添加留言
//             Column(
//               children: [
//                 TextField(
//                   controller: _messageController,
//                   focusNode: _focusNode,
//                   minLines: 2,
//                   maxLines: null,
//                   decoration: InputDecoration(
//                     hintText: '添加留言...',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(24.0),
//                       borderSide: BorderSide(color: Colors.grey[300]!),
//                     ),
//                     focusedBorder: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(24.0),
//                       borderSide: BorderSide(
//                         color: Theme.of(context).primaryColor,
//                       ),
//                     ),
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 16.0,
//                       vertical: 12.0,
//                     ),
//                   ),
//                   onTapOutside: (event) => _focusNode.unfocus(),
//                 ),
//                 const SizedBox(width: 8.0),
//                 // TODO: routine的表情添加可以置于此?
//                 Align(
//                   alignment: Alignment.centerRight,
//                   child: IconButton(
//                     onPressed: _addMessage,
//                     icon: Icon(
//                       Icons.send,
//                       color: Theme.of(context).primaryColor,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _showModify(BuildContext context, WidgetRef ref) {
//     showModalBottomSheet(
//       isScrollControlled: true,
//       context: context,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => RetagWidget(_currentEssay, _retag),
//     );
//   }
// }
