// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'countdown_timer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$countdownTimersHash() => r'd9a99b5dc0267033100b1344f7242f2e1eb96d90';

/// 倒计时器管理Provider (keepAlive: true 保证在应用内全程存活)
///
/// Copied from [CountdownTimers].
@ProviderFor(CountdownTimers)
final countdownTimersProvider =
    NotifierProvider<CountdownTimers, CountdownTimersState>.internal(
  CountdownTimers.new,
  name: r'countdownTimersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$countdownTimersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$CountdownTimers = Notifier<CountdownTimersState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
