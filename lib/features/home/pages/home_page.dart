import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/features/home/widgets/menu_button.dart';

// 将魔法数字提取为常量，提高可维护性
const double _menuWidthRatio = 0.7;
const Duration _animationDuration = Duration(milliseconds: 250);
const double _largeSpacing = 60.0;
const double _mediumSpacing = 30.0;
const double _smallSpacing = 8.0;
const double _buttonVerticalPadding = 3.0;
const double _dividerThickness = 1.2;
const double _boxShadowBlurRadius = 14.0;
const double _boxShadowSpreadRadius = 1.0;
const Offset _boxShadowOffset = Offset(4, 0);
const double _imageOpacity = 0.28; // 对应 Color(0x47FFFFFF)

class HomePage extends StatefulWidget {
  final int bgIndex;
  const HomePage({super.key, required this.bgIndex});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  // _isMenuOpen 布尔变量来控制
  bool _isMenuOpen = false;

  final List<ButtonInfo> _buttonInfos = [
    const ButtonInfo(name: "积微", icon: Icons.book, route: "booklet"),
    const ButtonInfo(name: "随笔", icon: Icons.description, route: "essay"),
    const ButtonInfo(
      name: "待办",
      icon: IconData(0xe62e, fontFamily: "iconfont"),
      route: "todo",
    ),
    const ButtonInfo(name: "阅读", icon: Icons.newspaper, route: "news"),
    const ButtonInfo(
      name: "其他",
      icon: Icons.account_tree_rounded,
      route: "others",
    ),
    const ButtonInfo(name: "个人", icon: Icons.person, route: "profile"),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 切换菜单的显示与隐藏，并控制动画播放
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMenuOpen ? _controller.forward() : _controller.reverse();
    });
  }

  /// 根据路由名称导航，并在导航后关闭菜单
  void _navigateTo(String route) {
    context.pushNamed(route);
    if (_isMenuOpen) {
      _toggleMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final menuWidth = size.width * _menuWidthRatio;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // 1. 主内容区域
          GestureDetector(
            onTap: !_isMenuOpen ? _toggleMenu : null,
            child: Container(
              constraints: BoxConstraints.expand(),
              child: Image.asset(
                "assets/images/${widget.bgIndex}.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. 背景遮罩
          FadeTransition(
            opacity: _opacityAnimation,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(color: Colors.black),
            ),
          ),

          // 3. 侧边菜单
          SlideTransition(
            position: _slideAnimation,
            child: Container(
              width: menuWidth,
              height: size.height,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage("assets/images/soldier.png"),
                  fit: BoxFit.cover,
                  opacity: _imageOpacity,
                ),
                color: AppTheme.surfaceContainer,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(
                      30,
                    ), // 0.12 opacity -> 30 alpha
                    blurRadius: _boxShadowBlurRadius,
                    spreadRadius: _boxShadowSpreadRadius,
                    offset: _boxShadowOffset,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: _largeSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _mediumSpacing,
                      vertical: _smallSpacing,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "理想如星\n虽不能及,吾心往之",
                        style: TextStyle(
                          fontFamily: "kaiti",
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  Divider(
                    height: _mediumSpacing,
                    thickness: _dividerThickness,
                    color: AppTheme.primaryContainer.withAlpha(
                      102,
                    ), // 0.4 opacity -> 102 alpha
                    indent: _mediumSpacing,
                    endIndent: _mediumSpacing,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _buttonInfos.length - 1,
                      itemBuilder: (context, index) {
                        final button = _buttonInfos[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: _buttonVerticalPadding,
                          ),
                          child: MenuButton(
                            info: button,
                            func: _navigateTo,
                            textColor: AppTheme.onSurface,
                            highlightColor: AppTheme.primaryContainer.withAlpha(
                              77,
                            ), // 0.3 opacity -> 77 alpha
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _mediumSpacing,
                      vertical: _smallSpacing,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.surfaceContainerHighest.withAlpha(
                          77,
                        ), // 0.3 opacity -> 77 alpha
                      ),
                      child: MenuButton(
                        info: _buttonInfos.last,
                        func: _navigateTo,
                        textColor: AppTheme.primary,
                        highlightColor: AppTheme.primaryContainer.withAlpha(
                          64,
                        ), // 0.25 opacity -> 64 alpha
                      ),
                    ),
                  ),
                  const SizedBox(height: _largeSpacing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
