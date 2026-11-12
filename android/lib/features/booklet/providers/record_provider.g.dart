// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'record_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 根据 styleId 返回关联的倒序排列的所有 Records

@ProviderFor(recordsByStyleId)
final recordsByStyleIdProvider = RecordsByStyleIdFamily._();

/// 根据 styleId 返回关联的倒序排列的所有 Records

final class RecordsByStyleIdProvider
    extends $FunctionalProvider<List<Record>, List<Record>, List<Record>>
    with $Provider<List<Record>> {
  /// 根据 styleId 返回关联的倒序排列的所有 Records
  RecordsByStyleIdProvider._({
    required RecordsByStyleIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'recordsByStyleIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordsByStyleIdHash();

  @override
  String toString() {
    return r'recordsByStyleIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<Record>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Record> create(Ref ref) {
    final argument = this.argument as String;
    return recordsByStyleId(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Record> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Record>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordsByStyleIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordsByStyleIdHash() => r'23794aa2892bc843bc4aba1ef01c1461287d3474';

/// 根据 styleId 返回关联的倒序排列的所有 Records

final class RecordsByStyleIdFamily extends $Family
    with $FunctionalFamilyOverride<List<Record>, String> {
  RecordsByStyleIdFamily._()
    : super(
        retry: null,
        name: r'recordsByStyleIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据 styleId 返回关联的倒序排列的所有 Records

  RecordsByStyleIdProvider call(String styleId) =>
      RecordsByStyleIdProvider._(argument: styleId, from: this);

  @override
  String toString() => r'recordsByStyleIdProvider';
}

/// 根据日期获取 Record

@ProviderFor(recordByDate)
final recordByDateProvider = RecordByDateFamily._();

/// 根据日期获取 Record

final class RecordByDateProvider
    extends $FunctionalProvider<Record?, Record?, Record?>
    with $Provider<Record?> {
  /// 根据日期获取 Record
  RecordByDateProvider._({
    required RecordByDateFamily super.from,
    required DateTime super.argument,
  }) : super(
         retry: null,
         name: r'recordByDateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$recordByDateHash();

  @override
  String toString() {
    return r'recordByDateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Record?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Record? create(Ref ref) {
    final argument = this.argument as DateTime;
    return recordByDate(ref, targetDate: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Record? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Record?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RecordByDateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$recordByDateHash() => r'fdf2749e1e5a20994103f3060646f629beb2fc66';

/// 根据日期获取 Record

final class RecordByDateFamily extends $Family
    with $FunctionalFamilyOverride<Record?, DateTime> {
  RecordByDateFamily._()
    : super(
        retry: null,
        name: r'recordByDateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据日期获取 Record

  RecordByDateProvider call({required DateTime targetDate}) =>
      RecordByDateProvider._(argument: targetDate, from: this);

  @override
  String toString() => r'recordByDateProvider';
}

/// 各任务的完成次数，忽略不属于该计划的任务。

@ProviderFor(allTaskCompletionCounts)
final allTaskCompletionCountsProvider = AllTaskCompletionCountsFamily._();

/// 各任务的完成次数，忽略不属于该计划的任务。

final class AllTaskCompletionCountsProvider
    extends
        $FunctionalProvider<
          Map<String, int>,
          Map<String, int>,
          Map<String, int>
        >
    with $Provider<Map<String, int>> {
  /// 各任务的完成次数，忽略不属于该计划的任务。
  AllTaskCompletionCountsProvider._({
    required AllTaskCompletionCountsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'allTaskCompletionCountsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$allTaskCompletionCountsHash();

  @override
  String toString() {
    return r'allTaskCompletionCountsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<Map<String, int>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Map<String, int> create(Ref ref) {
    final argument = this.argument as String;
    return allTaskCompletionCounts(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, int>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AllTaskCompletionCountsProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$allTaskCompletionCountsHash() =>
    r'6bd7c673d7b0fc9804fda32b246953a887855b30';

/// 各任务的完成次数，忽略不属于该计划的任务。

final class AllTaskCompletionCountsFamily extends $Family
    with $FunctionalFamilyOverride<Map<String, int>, String> {
  AllTaskCompletionCountsFamily._()
    : super(
        retry: null,
        name: r'allTaskCompletionCountsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 各任务的完成次数，忽略不属于该计划的任务。

  AllTaskCompletionCountsProvider call(String styleId) =>
      AllTaskCompletionCountsProvider._(argument: styleId, from: this);

  @override
  String toString() => r'allTaskCompletionCountsProvider';
}

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。

@ProviderFor(currentStreak)
final currentStreakProvider = CurrentStreakFamily._();

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。

final class CurrentStreakProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。
  CurrentStreakProvider._({
    required CurrentStreakFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'currentStreakProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$currentStreakHash();

  @override
  String toString() {
    return r'currentStreakProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    final argument = this.argument as String;
    return currentStreak(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CurrentStreakProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$currentStreakHash() => r'c9e9589fb4fc44774a9dd40f753d65bfe4fa9827';

/// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。

final class CurrentStreakFamily extends $Family
    with $FunctionalFamilyOverride<int, String> {
  CurrentStreakFamily._()
    : super(
        retry: null,
        name: r'currentStreakProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 截至今天或昨天的连续打卡天数；两天均未打卡则为 0。

  CurrentStreakProvider call(String styleId) =>
      CurrentStreakProvider._(argument: styleId, from: this);

  @override
  String toString() => r'currentStreakProvider';
}

/// 根据 Style 获取该 Style 的日期范围

@ProviderFor(styleDateRange)
final styleDateRangeProvider = StyleDateRangeFamily._();

/// 根据 Style 获取该 Style 的日期范围

final class StyleDateRangeProvider
    extends
        $FunctionalProvider<
          DateTimeRange<DateTime>?,
          DateTimeRange<DateTime>?,
          DateTimeRange<DateTime>?
        >
    with $Provider<DateTimeRange<DateTime>?> {
  /// 根据 Style 获取该 Style 的日期范围
  StyleDateRangeProvider._({
    required StyleDateRangeFamily super.from,
    required Style? super.argument,
  }) : super(
         retry: null,
         name: r'styleDateRangeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$styleDateRangeHash();

  @override
  String toString() {
    return r'styleDateRangeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<DateTimeRange<DateTime>?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTimeRange<DateTime>? create(Ref ref) {
    final argument = this.argument as Style?;
    return styleDateRange(ref, style: argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTimeRange<DateTime>? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTimeRange<DateTime>?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is StyleDateRangeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$styleDateRangeHash() => r'a85c583d72ae8856cbf4c9f193c4b1870b90a116';

/// 根据 Style 获取该 Style 的日期范围

final class StyleDateRangeFamily extends $Family
    with $FunctionalFamilyOverride<DateTimeRange<DateTime>?, Style?> {
  StyleDateRangeFamily._()
    : super(
        retry: null,
        name: r'styleDateRangeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 根据 Style 获取该 Style 的日期范围

  StyleDateRangeProvider call({required Style? style}) =>
      StyleDateRangeProvider._(argument: style, from: this);

  @override
  String toString() => r'styleDateRangeProvider';
}
