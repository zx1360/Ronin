import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
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

class HomePage extends ConsumerStatefulWidget {
  /// 背景图片相对路径，为空字符串或null时使用默认背景
  final String? bgPath;
  const HomePage({super.key, this.bgPath});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  // _isMenuOpen 布尔变量来控制
  bool _isMenuOpen = false;

  // 个性化配置
  final PersonalizationService _personalizationService = PersonalizationService();
  late String _motto;
  String? _sidebarImagePath;
  File? _bgFile;
  File? _sidebarFile;

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

    // 初始化个性化配置
    _initPersonalization();
  }

  /// 初始化个性化配置
  Future<void> _initPersonalization() async {
    _motto = _personalizationService.getRandomMotto();
    _sidebarImagePath = _personalizationService.getRandomSidebarImage();

    // 加载背景图片文件
    if (widget.bgPath != null && widget.bgPath!.isNotEmpty) {
      _bgFile = await IoService.getImageFile(widget.bgPath!);
    }

    // 加载侧边栏图片文件
    if (_sidebarImagePath != null) {
      _sidebarFile = await IoService.getImageFile(_sidebarImagePath!);
    }

    if (mounted) setState(() {});
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
          // 1. 主内容区域（背景）
          GestureDetector(
            onTap: !_isMenuOpen ? _toggleMenu : null,
            child: Container(
              constraints: const BoxConstraints.expand(),
              child: _buildMainBackground(),
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
            child: _buildSideMenu(menuWidth, size.height),
          ),
        ],
      ),
    );
  }

  /// 构建主背景
  Widget _buildMainBackground() {
    // 优先使用自定义背景图
    if (_bgFile != null) {
      return Image.file(
        _bgFile!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildDefaultMainBackground(),
      );
    }
    return _buildDefaultMainBackground();
  }

  /// 默认主背景（简约渐变 + TORRID logo）
  Widget _buildDefaultMainBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary.withAlpha(200),
            AppTheme.primaryContainer,
            AppTheme.surface,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用logo或图标
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(60),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 60,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'TORRID',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '热情生活，每一天',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建侧边菜单
  Widget _buildSideMenu(double menuWidth, double height) {
    return Container(
      width: menuWidth,
      height: height,
      decoration: _buildSideMenuDecoration(),
      child: Column(
        children: [
          const SizedBox(height: _largeSpacing),
          // 座右铭
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _mediumSpacing,
              vertical: _smallSpacing,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _motto,
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
            color: AppTheme.primaryContainer.withAlpha(102),
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
                    highlightColor: AppTheme.primaryContainer.withAlpha(77),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _mediumSpacing,
              vertical: _smallSpacing,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.surfaceContainerHighest.withAlpha(77),
              ),
              child: MenuButton(
                info: _buttonInfos.last,
                func: _navigateTo,
                textColor: AppTheme.primary,
                highlightColor: AppTheme.primaryContainer.withAlpha(64),
              ),
            ),
          ),
          const SizedBox(height: _largeSpacing),
        ],
      ),
    );
  }

  /// 构建侧边菜单装饰
  BoxDecoration _buildSideMenuDecoration() {
    // 如果有自定义侧边栏图片
    if (_sidebarFile != null) {
      return BoxDecoration(
        image: DecorationImage(
          image: FileImage(_sidebarFile!),
          fit: BoxFit.cover,
          opacity: _imageOpacity,
          onError: (_, __) {
            // 图片加载失败时不显示图片
          },
        ),
        color: AppTheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: _boxShadowBlurRadius,
            spreadRadius: _boxShadowSpreadRadius,
            offset: _boxShadowOffset,
          ),
        ],
      );
    }

    // 默认简约样式（无背景图）
    return BoxDecoration(
      color: AppTheme.surfaceContainer,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(30),
          blurRadius: _boxShadowBlurRadius,
          spreadRadius: _boxShadowSpreadRadius,
          offset: _boxShadowOffset,
        ),
      ],
    );
  }
}
