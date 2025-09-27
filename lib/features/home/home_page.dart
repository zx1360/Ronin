import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme_light.dart';
import 'package:torrid/features/home/widgets/menu_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // 随机获取一张图片作为大屏壁纸
  final randomIndex = (Random().nextInt(6) + 1).toString();

  // 动画控制器，用于管理菜单滑入滑出动画
  late AnimationController _controller;
  // 侧边菜单滑行动画
  late Animation<Offset> _slideAnimation;
  // 背景遮罩透明度动画
  late Animation<double> _opacityAnimation;
  // 菜单是否打开的状态
  bool _isMenuOpen = false;

  // 菜单按钮数据列表
  final List<ButtonInfo> _buttonInfos = [
    ButtonInfo(name: "积微", icon: Icons.book, route: "booklet"),
    ButtonInfo(name: "随笔", icon: Icons.description, route: "essay"),
    ButtonInfo(name: "早报", icon: Icons.newspaper, route: "news"),
    ButtonInfo(name: "其他", icon: Icons.account_tree_rounded, route: "others"),
    ButtonInfo(name: "个人", icon: Icons.person, route: "profile"),
  ];

  @override
  void initState() {
    super.initState();
    // 初始化动画控制器，时长300毫秒
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // 侧边菜单滑入动画：从左侧屏幕外滑到屏幕内
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // 背景遮罩动画：从完全透明到半透明
    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    // 释放动画控制器资源
    _controller.dispose();
    super.dispose();
  }

  // 切换菜单显示/隐藏状态
  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      // 根据菜单状态控制动画播放方向
      _isMenuOpen ? _controller.forward() : _controller.reverse();
    });
  }

  // 导航到指定路由
  void _navigateTo(String route) {
    // 使用go_router进行路由跳转
    context.pushNamed(route);
    // 导航后关闭菜单
    if (_isMenuOpen) {
      _toggleMenu();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // 侧边菜单宽度为屏幕宽度的70%
    final menuWidth = size.width * 0.7;

    return Scaffold(
      body: Stack(
        children: [
          // 1. 主内容区域 - 点击任意位置触发菜单
          GestureDetector(
            // 只有当菜单关闭时，点击主区域才会打开菜单
            onTap: !_isMenuOpen ? _toggleMenu : null,
            child: Container(
              constraints: BoxConstraints.expand(),
              child: Image.asset(
                "assets/images/$randomIndex.jpg",
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. 背景遮罩 - 只在菜单打开时显示，点击遮罩关闭菜单
          if (_isMenuOpen)
            FadeTransition(
              opacity: _opacityAnimation,
              child: GestureDetector(
                onTap: _toggleMenu,
                // 遮罩只覆盖菜单以外的区域
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
                image: const DecorationImage(
                  image: AssetImage("assets/images/soldier.png"),
                  fit: BoxFit.cover,
                  opacity: 0.28,
                ),
                color: AppTheme.lightCardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: const Offset(4, 0),
                  ),
                ],
              ),
              child: AbsorbPointer(
                absorbing: false,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "理想如星\n虽不能及,吾心往之",
                          style: TextStyle(
                            fontFamily: "kaiti",
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColorDark,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 30,
                      thickness: 1.2,
                      color: AppTheme.primaryColorLight.withOpacity(0.4),
                      indent: 20,
                      endIndent: 20,
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _buttonInfos.length - 1,
                        itemBuilder: (context, index) {
                          final button = _buttonInfos[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: MenuButton(
                              info: button,
                              func: _navigateTo,
                              textColor: AppTheme.darkTextColor,
                              highlightColor: AppTheme.primaryColorLight
                                  .withOpacity(0.3),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.lightSurfaceColor.withOpacity(0.3),
                        ),
                        child: MenuButton(
                          info: _buttonInfos.last,
                          func: _navigateTo,
                          textColor: AppTheme.primaryColorDark,
                          highlightColor: AppTheme.primaryColorLight
                              .withOpacity(0.25),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
