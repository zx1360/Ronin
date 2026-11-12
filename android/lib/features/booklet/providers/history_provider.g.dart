// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookletHistory)
final bookletHistoryProvider = BookletHistoryFamily._();

final class BookletHistoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<BookletHistoryEntry>>,
          List<BookletHistoryEntry>,
          FutureOr<List<BookletHistoryEntry>>
        >
    with
        $FutureModifier<List<BookletHistoryEntry>>,
        $FutureProvider<List<BookletHistoryEntry>> {
  BookletHistoryProvider._({
    required BookletHistoryFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'bookletHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookletHistoryHash();

  @override
  String toString() {
    return r'bookletHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<BookletHistoryEntry>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<BookletHistoryEntry>> create(Ref ref) {
    final argument = this.argument as String?;
    return bookletHistory(ref, styleId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookletHistoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookletHistoryHash() => r'f2101552679a8196d7362a79ed4d370960bb4168';

final class BookletHistoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<BookletHistoryEntry>>,
          String?
        > {
  BookletHistoryFamily._()
    : super(
        retry: null,
        name: r'bookletHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BookletHistoryProvider call({String? styleId}) =>
      BookletHistoryProvider._(argument: styleId, from: this);

  @override
  String toString() => r'bookletHistoryProvider';
}
