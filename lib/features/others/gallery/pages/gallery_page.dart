import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:torrid/features/others/gallery/pages/setting_page.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool isPreviewAllowed = true;

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
                    icon: Icon(Icons.arrow_back),
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
                    icon: Icon(Icons.settings),
                    tooltip: "设置",
                  ),
                ),
              ],
            ),

            // 主体内容
            Expanded(child: Center(child: Text("gallery库主页面"))),

            // 底部导航栏
            SafeArea(
              child: Container(
                height: 42,
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(const IconData(0xe63e, fontFamily: "iconfont")),
                      tooltip: "标签",
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(const IconData(0xe606, fontFamily: "iconfont")),
                      tooltip: "绑定",
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(const IconData(0xe649, fontFamily: "iconfont")),
                      tooltip: "删除?",
                    ),
                    // 切换实现
                    Switch(
                      value: isPreviewAllowed,
                      onChanged: (bool value) {
                        setState(() {
                          isPreviewAllowed = value;
                        });
                      },
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
