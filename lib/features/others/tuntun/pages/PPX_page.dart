import 'package:flutter/material.dart';

class TuntunPage extends StatelessWidget {
  const TuntunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text("TunTun_page.")));
  }
}


// import 'package:flutter/material.dart';
// import 'package:video_player/video_player.dart';

// class TuntunPage extends StatefulWidget {
//   const TuntunPage({super.key});

//   @override
//   State<TuntunPage> createState() => _TuntunPageState();
// }

// class _TuntunPageState extends State<TuntunPage> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;

//   // 模拟视频数据
//   final List<VideoData> _videos = [
//     VideoData(
//       id: 1,
//       url: 'https://assets.mixkit.co/videos/preview/mixkit-dog-playing-in-the-snow-4565-large.mp4',
//       coverImage: 'https://picsum.photos/800/1400?random=1',
//       title: '太可爱了！狗狗在雪地里玩耍',
//       user: User(
//         name: '宠物乐园',
//         avatar: 'https://picsum.photos/100/100?random=101',
//         verified: true,
//       ),
//       likes: 12543,
//       comments: 892,
//       shares: 456,
//       tags: ['#宠物', '#狗狗', '#雪地'],
//     ),
//     VideoData(
//       id: 2,
//       url: 'https://assets.mixkit.co/videos/preview/mixkit-waterfall-in-forest-221-large.mp4',
//       coverImage: 'https://picsum.photos/800/1400?random=2',
//       title: '大自然的声音，治愈你的心灵',
//       user: User(
//         name: '户外探险',
//         avatar: 'https://picsum.photos/100/100?random=102',
//         verified: false,
//       ),
//       likes: 8765,
//       comments: 345,
//       shares: 234,
//       tags: ['#自然', '#美景', '#治愈'],
//     ),
//     VideoData(
//       id: 3,
//       url: 'https://assets.mixkit.co/videos/preview/mixkit-city-traffic-at-night-4674-large.mp4',
//       coverImage: 'https://picsum.photos/800/1400?random=3',
//       title: '城市夜景延时摄影，美到窒息',
//       user: User(
//         name: '摄影爱好者',
//         avatar: 'https://picsum.photos/100/100?random=103',
//         verified: true,
//       ),
//       likes: 23456,
//       comments: 1234,
//       shares: 876,
//       tags: ['#城市', '#夜景', '#摄影'],
//     ),
//   ];

//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           PageView.builder(
//             controller: _pageController,
//             scrollDirection: Axis.vertical,
//             itemCount: _videos.length,
//             onPageChanged: (index) {
//               setState(() {
//                 _currentPage = index;
//               });
//             },
//             itemBuilder: (context, index) {
//               return VideoPlayerItem(video: _videos[index]);
//             },
//           ),
//           // 顶部导航栏
//           Positioned(
//             top: 0,
//             left: 0,
//             right: 0,
//             child: SafeArea(
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
//                       onPressed: () => Navigator.pop(context),
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.search, color: Colors.white, size: 24),
//                       onPressed: () {},
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           // 右侧互动按钮
//           Positioned(
//             right: 0,
//             top: 0,
//             bottom: 0,
//             child: SafeArea(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   UserAvatar(
//                     avatarUrl: _videos[_currentPage].user.avatar,
//                     verified: _videos[_currentPage].user.verified,
//                   ),
//                   const SizedBox(height: 20),
//                   ActionButton(
//                     icon: Icons.favorite,
//                     label: formatNumber(_videos[_currentPage].likes),
//                     color: Colors.white,
//                   ),
//                   const SizedBox(height: 20),
//                   ActionButton(
//                     icon: Icons.comment,
//                     label: formatNumber(_videos[_currentPage].comments),
//                     color: Colors.white,
//                   ),
//                   const SizedBox(height: 20),
//                   ActionButton(
//                     icon: Icons.share,
//                     label: formatNumber(_videos[_currentPage].shares),
//                     color: Colors.white,
//                   ),
//                   const SizedBox(height: 20),
//                   const RotationIconButton(
//                     icon: Icons.reply,
//                     color: Colors.white,
//                   ),
//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//           // 底部内容
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: SafeArea(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     RichText(
//                       text: TextSpan(
//                         children: [
//                           TextSpan(
//                             text: _videos[_currentPage].user.name,
//                             style: const TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.white,
//                             ),
//                           ),
//                           if (_videos[_currentPage].user.verified)
//                             const WidgetSpan(
//                               child: Padding(
//                                 padding: EdgeInsets.symmetric(horizontal: 4),
//                                 child: Icon(Icons.check_circle, color: Colors.blue, size: 16),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       _videos[_currentPage].title,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Wrap(
//                       spacing: 8,
//                       children: _videos[_currentPage].tags
//                           .map((tag) => Text(
//                                 tag,
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.white70,
//                                 ),
//                               ))
//                           .toList(),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // 格式化数字显示
//   String formatNumber(int number) {
//     if (number >= 10000) {
//       return '${(number / 10000).toStringAsFixed(1)}w';
//     } else if (number >= 1000) {
//       return '${(number / 1000).toStringAsFixed(1)}k';
//     }
//     return number.toString();
//   }
// }

// class VideoPlayerItem extends StatefulWidget {
//   final VideoData video;

//   const VideoPlayerItem({super.key, required this.video});

//   @override
//   State<VideoPlayerItem> createState() => _VideoPlayerItemState();
// }

// class _VideoPlayerItemState extends State<VideoPlayerItem> {
//   late VideoPlayerController _controller;
//   bool _isPlaying = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.network(widget.video.url)
//       ..initialize().then((_) {
//         setState(() {});
//         _controller.play();
//         _controller.setLooping(true);
//         _isPlaying = true;
//       });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         // 视频播放器
//         _controller.value.isInitialized
//             ? AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: VideoPlayer(_controller),
//               )
//             : Image.network(
//                 widget.video.coverImage,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 height: double.infinity,
//               ),
//         // 视频播放/暂停控制
//         GestureDetector(
//           onTap: () {
//             setState(() {
//               if (_controller.value.isPlaying) {
//                 _controller.pause();
//                 _isPlaying = false;
//               } else {
//                 _controller.play();
//                 _isPlaying = true;
//               }
//             });
//           },
//           child: Container(
//             color: Colors.transparent,
//             width: double.infinity,
//             height: double.infinity,
//           ),
//         ),
//         // 播放/暂停按钮
//         if (!_isPlaying)
//           Center(
//             child: Container(
//               width: 64,
//               height: 64,
//               decoration: const BoxDecoration(
//                 color: Colors.black54,
//                 shape: BoxShape.circle,
//               ),
//               child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
//             ),
//           ),
//       ],
//     );
//   }
// }

// class UserAvatar extends StatelessWidget {
//   final String avatarUrl;
//   final bool verified;

//   const UserAvatar({super.key, required this.avatarUrl, this.verified = false});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Stack(
//           children: [
//             Container(
//               width: 50,
//               height: 50,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(color: Colors.white, width: 2),
//               ),
//               child: ClipOval(
//                 child: Image.network(
//                   avatarUrl,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//             ),
//             if (verified)
//               const Positioned(
//                 bottom: 0,
//                 right: 0,
//                 child: Icon(Icons.add_circle, color: Colors.orange, size: 18),
//               ),
//           ],
//         ),
//         const SizedBox(height: 4),
//         const Icon(Icons.add, color: Colors.white, size: 18),
//       ],
//     );
//   }
// }

// class ActionButton extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;

//   const ActionButton({super.key, required this.icon, required this.label, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           width: 40,
//           height: 40,
//           decoration: BoxDecoration(
//             color: Colors.black26,
//             shape: BoxShape.circle,
//           ),
//           child: Icon(icon, color: color, size: 20),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 12,
//             color: color,
//           ),
//         ),
//       ],
//     );
//   }
// }

// class RotationIconButton extends StatelessWidget {
//   final IconData icon;
//   final Color color;

//   const RotationIconButton({super.key, required this.icon, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 40,
//       height: 40,
//       decoration: BoxDecoration(
//         color: Colors.black26,
//         shape: BoxShape.circle,
//       ),
//       child: RotatedBox(
//         quarterTurns: 1,
//         child: Icon(icon, color: color, size: 20),
//       ),
//     );
//   }
// }

// // 数据模型
// class VideoData {
//   final int id;
//   final String url;
//   final String coverImage;
//   final String title;
//   final User user;
//   final int likes;
//   final int comments;
//   final int shares;
//   final List<String> tags;

//   VideoData({
//     required this.id,
//     required this.url,
//     required this.coverImage,
//     required this.title,
//     required this.user,
//     required this.likes,
//     required this.comments,
//     required this.shares,
//     required this.tags,
//   });
// }

// class User {
//   final String name;
//   final String avatar;
//   final bool verified;

//   User({
//     required this.name,
//     required this.avatar,
//     this.verified = false,
//   });
// }