import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/io/io_service.dart';
import 'package:torrid/core/services/personalization/personalization_service.dart';
import 'package:torrid/core/services/storage/prefs_service.dart';
import 'package:torrid/features/home/widgets/default_background.dart';
import 'package:torrid/features/home/back_handler.dart';
import 'package:torrid/providers/personalization/personalization_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  final String? bgPath;
  const HomePage({super.key, this.bgPath});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _personalization = PersonalizationService();
  String _motto = '';
  File? _background, _sidebar;
  int _load = 0;

  static const _destinations = [
    (
      label: '积微',
      icon: Icons.check_circle_outline_rounded,
      route: 'booklet',
      hint: '记录每天的小事',
    ),
    (label: '随笔', icon: Icons.edit_note_rounded, route: 'essay', hint: '书写与回读'),
    (
      label: '对话',
      icon: Icons.chat_bubble_outline_rounded,
      route: 'chat',
      hint: '聊天与近期回顾',
    ),
    (
      label: '媒体',
      icon: Icons.photo_library_outlined,
      route: 'others',
      hint: '漫画、藏品与相册',
    ),
    (
      label: '阅读',
      icon: Icons.auto_stories_outlined,
      route: 'news',
      hint: '资讯与常用网站',
    ),
    (
      label: '个人与设置',
      icon: Icons.tune_rounded,
      route: 'profile',
      hint: '连接、同步与本机存储',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reloadPersonalization(initial: true);
  }

  Future<void> _reloadPersonalization({bool initial = false}) async {
    final generation = ++_load;
    final path = initial && widget.bgPath?.isNotEmpty == true
        ? widget.bgPath
        : _personalization.getRandomBackgroundImage();
    final sidebar = _personalization.getRandomSidebarImage();
    final motto = _personalization.getRandomMotto();
    final images = await Future.wait([
      path == null ? Future<File?>.value() : IoService.getImageFile(path),
      sidebar == null ? Future<File?>.value() : IoService.getImageFile(sidebar),
    ]);
    if (!mounted || generation != _load) return;
    setState(() {
      _motto = motto;
      _background = images[0];
      _sidebar = images[1];
    });
  }

  void _open(String route) {
    _scaffold.currentState?.closeDrawer();
    context.pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettings>(appSettingsProvider, (previous, next) {
      if (previous != next) _reloadPersonalization();
    });
    final colors = Theme.of(context).colorScheme;
    return BackHandler(
      onBack: () {
        if (_scaffold.currentState?.isDrawerOpen != true) return false;
        _scaffold.currentState?.closeDrawer();
        return true;
      },
      child: Scaffold(
        key: _scaffold,
        drawer: Drawer(
          child: Container(
            decoration: BoxDecoration(
              image: _sidebar == null
                  ? null
                  : DecorationImage(
                      image: FileImage(_sidebar!),
                      fit: BoxFit.cover,
                      opacity: .16,
                      onError: (_, _) {},
                    ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _motto,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'kaiti',
                          color: colors.primary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(indent: 24, endIndent: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in _destinations)
                          ListTile(
                            leading: Icon(item.icon, color: colors.primary),
                            title: Text(item.label),
                            subtitle: Text(item.hint),
                            onTap: () => _open(item.route),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            BackgroundWidget(imageFile: _background, showBrand: false),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: '打开功能菜单',
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: () => _scaffold.currentState?.openDrawer(),
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          tooltip: '个人与设置',
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: () => _open('profile'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: _background == null
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TorridBrand(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Card(
                      margin: EdgeInsets.zero,
                      color: colors.surface.withValues(alpha: .95),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '从这里开始',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                for (final item in _destinations.take(3))
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 4,
                                          ),
                                        ),
                                        onPressed: () => _open(item.route),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(item.icon, size: 22),
                                            const SizedBox(height: 6),
                                            Text(item.label),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _open('others'),
                              icon: const Icon(
                                Icons.photo_library_outlined,
                                size: 20,
                              ),
                              label: const Text('漫画、藏品与相册'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.background,
      ),
    );
  }
}
