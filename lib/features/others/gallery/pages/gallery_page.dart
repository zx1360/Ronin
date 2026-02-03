import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torrid/features/others/gallery/pages/setting_page.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/content_widget.dart';

// PS:gallery模块主要页面, 
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool isPreviewAllowed = true;
  // PS: '媒体文件队列排序规则: 按照media_assets表的captured_at时间升序排列.'
  // 持久化维护modified_count变量, 它表示当前最后一次与媒体文件相关的操作(给文件增删标签, 标记删除文件, 绑定文件等)的那个媒体文件在当前media_assets表中的按'媒体文件队列排序规则'所处的位置序号.

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
    ));
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部导航栏
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: "返回",
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GallerySettingPage()),
                    ),
                    icon: const Icon(Icons.settings),
                    tooltip: "设置",
                  ),
                ),
              ],
            ),

            // 主体内容, 展示当前媒体文件(图片/视频)
            Expanded(child: Center(child: ContentWidget())),

            // 底部导航栏
            SafeArea(
              child: Container(
                height: 42,
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // PS: 打开LabelList组件, 进行标签管理/为当前这个媒体文件打标签等操作.
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(IconData(0xe63e, fontFamily: "iconfont")),
                      tooltip: "标签",
                    ),
                    // PS: 打开MediasGridView组件, 展示媒体文件网格视图, 以便快速浏览和选择其他媒体文件并进行相关操作.
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(IconData(0xe604, fontFamily: "iconfont")),
                      tooltip: "绑定",
                    ),
                    // PS: 将当前媒体文件标记为已删除(软删除), 即在media_assets表中将该记录的is_deleted字段置为true.
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(IconData(0xe649, fontFamily: "iconfont")),
                      tooltip: "删除当前媒体文件",
                    ),
                    // PS:当前媒体文件的详情页.
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(IconData(0xe611, fontFamily: "iconfont")),
                      tooltip: "详细页面",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
