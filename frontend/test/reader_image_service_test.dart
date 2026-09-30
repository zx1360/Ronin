import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:torrid/features/comic/services/reader_image_service.dart';

void main() {
  group('collectCropSegments', () {
    // 三张图，显示高度分别为 100 / 200 / 100
    const offsets = <double>[0, 100, 300, 400];

    test('选区落在单张图内', () {
      final segments = collectCropSegments(
        imageOffsets: offsets,
        startOffset: 120,
        endOffset: 180,
      );
      expect(segments, hasLength(1));
      expect(segments.single.imageIndex, 1);
      expect(segments.single.displayTop, 20);
      expect(segments.single.displayBottom, 80);
    });

    test('跨图选区按图切分', () {
      final segments = collectCropSegments(
        imageOffsets: offsets,
        startOffset: 50,
        endOffset: 350,
      );
      expect(segments.map((s) => s.imageIndex), [0, 1, 2]);
      expect(segments[0].displayTop, 50);
      expect(segments[0].displayBottom, 100);
      expect(segments[1].displayTop, 0);
      expect(segments[1].displayBottom, 200);
      expect(segments[2].displayTop, 0);
      expect(segments[2].displayBottom, 50);
    });

    test('越界选区被收敛到可用范围', () {
      final segments = collectCropSegments(
        imageOffsets: offsets,
        startOffset: -50,
        endOffset: 9999,
      );
      expect(segments, hasLength(3));
      expect(segments.first.displayTop, 0);
      expect(segments.last.displayBottom, 100);
    });

    test('空选区与不足两张图都返回空', () {
      expect(
        collectCropSegments(
          imageOffsets: offsets,
          startOffset: 100,
          endOffset: 100,
        ),
        isEmpty,
      );
      expect(
        collectCropSegments(
          imageOffsets: const [0],
          startOffset: 0,
          endOffset: 10,
        ),
        isEmpty,
      );
    });
  });

  group('mergeSegmentsToPng', () {
    test('宽度不同的段按首段宽度缩放后纵向拼接', () {
      final wide = img.Image(width: 4, height: 2);
      final narrow = img.Image(width: 2, height: 3);

      final merged = img.decodeImage(
        mergeSegmentsToPng([wide, narrow]),
      )!;

      expect(merged.width, 4);
      // 窄图按宽度 4 缩放后高度为 6
      expect(merged.height, 2 + 6);
    });

    test('空列表抛出可读异常', () {
      expect(
        () => mergeSegmentsToPng(const []),
        throwsA(isA<ReaderImageException>()),
      );
    });
  });

  test('decodeImageOrThrow 在无法解码时报出来源', () {
    expect(
      () => decodeImageOrThrow(Uint8List.fromList([1, 2, 3]), 'a/b.jpg'),
      throwsA(
        isA<ReaderImageException>().having(
          (e) => e.message,
          'message',
          contains('a/b.jpg'),
        ),
      ),
    );
  });
}
