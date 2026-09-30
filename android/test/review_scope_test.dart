import 'package:flutter_test/flutter_test.dart';
import 'package:torrid/features/chat/models/review_models.dart';

void main() {
  final today = DateTime(2026, 3, 30);

  group('ReviewScope 日期换算', () {
    test('按天数回溯，含首尾', () {
      const scope = ReviewScope(kind: ReviewRangeKind.days30);
      final span = scope.resolve(today);
      expect(span.from, '2026-03-01');
      expect(span.to, '2026-03-30');
      expect(scope.toRequestFields(today), {'days': 30});
    });

    test('近7天跨月正确', () {
      const scope = ReviewScope(kind: ReviewRangeKind.days7);
      expect(scope.resolve(today).from, '2026-03-24');
    });

    test('今年从 1 月 1 日起，并以显式 from/to 下发', () {
      const scope = ReviewScope(kind: ReviewRangeKind.thisYear);
      expect(scope.resolve(today).from, '2026-01-01');
      expect(scope.toRequestFields(today), {
        'from': '2026-01-01',
        'to': '2026-03-30',
      });
    });

    test('自定义范围用所选起止日期', () {
      final scope = ReviewScope(
        kind: ReviewRangeKind.custom,
        from: DateTime(2025, 12, 5),
        to: DateTime(2026, 1, 9),
      );
      expect(scope.isComplete, isTrue);
      expect(scope.toRequestFields(today), {
        'from': '2025-12-05',
        'to': '2026-01-09',
      });
      expect(scope.describe(today), '2025-12-05 ~ 2026-01-09');
    });

    test('自定义范围未选全或起晚于止时不完整', () {
      expect(
        const ReviewScope(kind: ReviewRangeKind.custom).isComplete,
        isFalse,
      );
      final reversed = ReviewScope(
        kind: ReviewRangeKind.custom,
        from: DateTime(2026, 3, 10),
        to: DateTime(2026, 3, 1),
      );
      expect(reversed.isComplete, isFalse);
    });

    test('预设档位默认是近30天', () {
      expect(const ReviewScope().kind, ReviewRangeKind.days30);
    });
  });

  group('ReviewPreset 本地校验', () {
    test('名称与角色都必填', () {
      expect(ReviewPreset.draft().problem, '预设名称不能为空');
      expect(
        ReviewPreset(id: 'a', name: '朋友', role: '', tone: '').problem,
        '角色设定不能为空',
      );
      expect(
        ReviewPreset(id: 'a', name: '朋友', role: '你是朋友', tone: '').problem,
        isNull,
      );
    });

    test('JSON 往返保留四个字段', () {
      final preset = ReviewPreset(
        id: 'a',
        name: '朋友',
        role: '你是朋友',
        tone: '温和',
      );
      final restored = ReviewPreset.fromJson(preset.toJson());
      expect(restored.id, 'a');
      expect(restored.name, '朋友');
      expect(restored.role, '你是朋友');
      expect(restored.tone, '温和');
    });
  });
}
