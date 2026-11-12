import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/app/theme/theme_book.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/core/services/storage/app_database.dart';
import 'package:torrid/features/others/gallery/models/media_asset.dart';
import 'package:torrid/features/others/gallery/pages/gallery_page.dart';
import 'package:torrid/features/others/gallery/pages/image_editor_page.dart';
import 'package:torrid/features/others/gallery/pages/media_detail_page.dart';
import 'package:torrid/features/others/gallery/pages/video_trimmer_page.dart';
import 'package:torrid/features/others/gallery/providers/gallery_providers.dart';
import 'package:torrid/features/others/gallery/widgets/main_widgets/gallery_video.dart';
import 'package:torrid/providers/api_client/api_client_provider.dart';

class _OfflineClient extends ApiClientManager {
  @override
  ApiClient build() {
    final client = _OfflineApi();
    ref.onDispose(client.close);
    return client;
  }
}

class _OfflineApi extends ApiClient {
  _OfflineApi() : super(baseUrl: '', retryConnections: false);

  @override
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParams,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async => throw const ApiException('测试离线');
}

class _BrowseSettings extends GalleryBrowseSettings {
  @override
  GalleryBrowseOptions build() => (
    autoOrientation: false,
    previewWindow: false,
    gridColumns: 4,
    gridMode: GalleryGridPreviewMode.thumb,
    autoApplyTags: false,
  );

  @override
  Future<void> setAutoOrientation(bool enabled) async {
    state = (
      autoOrientation: enabled,
      previewWindow: state.previewWindow,
      gridColumns: state.gridColumns,
      gridMode: state.gridMode,
      autoApplyTags: state.autoApplyTags,
    );
  }
}

Future<void> _withGallery(
  WidgetTester tester,
  List<MediaAsset> assets,
  Future<void> Function() verify,
) async {
  tester.view.physicalSize = const Size(320, 720);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  final database = AppDatabase(NativeDatabase.memory());
  final navigator = GlobalKey<NavigatorState>();
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          apiClientManagerProvider.overrideWith(_OfflineClient.new),
          galleryBrowseSettingsProvider.overrideWith(_BrowseSettings.new),
          galleryBrowsingAssetsProvider.overrideWith((_) => AsyncData(assets)),
          galleryBrowsingIndexProvider.overrideWith((_) => assets.length ~/ 2),
        ],
        child: MaterialApp(
          theme: AppTheme.bookTheme(),
          navigatorKey: navigator,
          home: const SizedBox.shrink(),
        ),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const GalleryPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await verify();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await database.close();
  }
}

void _cachePreview(MediaAsset asset) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(4, 4);
  picture.dispose();
  final key = CachedNetworkImageProvider(galleryMediaUrl('', asset));
  final cache = PaintingBinding.instance.imageCache;
  cache.putIfAbsent(
    key,
    () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: image))),
  );
  addTearDown(() => cache.evict(key));
}

void main() {
  testWidgets('Gallery 把媒体进度和操作收进更多，视频区保留系统边距', (tester) async {
    final date = DateTime(2026, 1, 1);
    const fileName =
        '2026-01-01_TheLongOriginalRecordingNameFromTheCameraWithItsSequenceNumber_00012.mp4';
    final clip = MediaAsset(
      id: 'current',
      createdAt: date,
      updatedAt: date,
      capturedAt: date,
      filePath: 'videos/$fileName',
      hash: 'current',
    );
    _cachePreview(clip);
    await _withGallery(
      tester,
      [clip.copyWith(id: 'first'), clip, clip.copyWith(id: 'last')],
      () async {
        final video = find.byType(GalleryVideo);
        expect(tester.getRect(video).top, 24);
        expect(tester.getRect(video).bottom, 720 - 24 - 40 - 56);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.textContaining('2 / 3'), findsNothing);
        expect(find.text(fileName), findsNothing);
        expect(
          tester.getCenter(find.text('更多')).dx,
          greaterThan(tester.getCenter(find.text('删除')).dx),
        );

        final visibility = find.byTooltip('显示/隐藏工具栏');
        await tester.tap(visibility);
        await tester.pumpAndSettle();
        expect(tester.getRect(video).bottom, 720 - 24);
        expect(find.text('更多'), findsNothing);
        await tester.tap(visibility);
        await tester.pumpAndSettle();

        Future<void> openMenu() async {
          await tester.tap(find.text('更多'));
          await tester.pump();
          expect(find.text('媒体管理设置').hitTestable(), findsOneWidget);
          expect(find.text('返回'), findsNothing);
        }

        await openMenu();
        final progress = find.byType(LinearProgressIndicator);
        expect(
          tester.widget<LinearProgressIndicator>(progress).value,
          closeTo(2 / 3, 0.001),
        );
        expect(find.text('浏览进度 · 2 / 3'), findsOneWidget);
        expect(find.text(fileName), findsOneWidget);
        expect(find.text('媒体管理设置'), findsOneWidget);
        final autoOrientation = find.byType(CheckedPopupMenuItem<void>);
        expect(
          tester.widget<CheckedPopupMenuItem<void>>(autoOrientation).checked,
          isFalse,
        );
        await tester.tap(autoOrientation);
        await tester.pumpAndSettle();
        await openMenu();
        expect(
          tester.widget<CheckedPopupMenuItem<void>>(autoOrientation).checked,
          isTrue,
        );
        await tester.tapAt(const Offset(16, 120));
        await tester.pumpAndSettle();
        expect(progress, findsNothing);

        await openMenu();
        await tester.tap(find.text('剪辑视频'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<VideoTrimmerPage>(find.byType(VideoTrimmerPage))
              .asset
              .id,
          clip.id,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        await openMenu();
        await tester.tap(find.text('详情'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<MediaDetailPage>(find.byType(MediaDetailPage)).asset.id,
          clip.id,
        );
        final name = find.widgetWithText(SelectableText, fileName);
        expect(name, findsOneWidget);
        final editable = tester
            .state<EditableTextState>(
              find.descendant(of: name, matching: find.byType(EditableText)),
            )
            .renderEditable;
        final start = editable.getLocalRectForCaret(
          const TextPosition(offset: 0),
        );
        final end = editable.getLocalRectForCaret(
          TextPosition(offset: fileName.length),
        );
        expect(end.top, greaterThan(start.top));
        expect(end.bottom, lessThanOrEqualTo(editable.size.height));
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('图片的更多菜单进入原有裁切页', (tester) async {
    final date = DateTime(2026, 1, 1);
    final photo = MediaAsset(
      id: 'photo',
      createdAt: date,
      updatedAt: date,
      capturedAt: date,
      filePath: 'photos/photo.jpg',
      hash: 'photo',
    );
    _cachePreview(photo);
    await _withGallery(tester, [photo], () async {
      await tester.tap(find.text('更多'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('剪辑视频'), findsNothing);
      await tester.tap(find.text('裁切图片'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        tester.widget<ImageEditorPage>(find.byType(ImageEditorPage)).asset.id,
        photo.id,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('空图库也可以打开更多和找到管理设置', (tester) async {
    await _withGallery(tester, [], () async {
      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();
      expect(find.text('媒体管理设置').hitTestable(), findsOneWidget);
      expect(
        find.byType(CheckedPopupMenuItem<void>).hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('详情'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
