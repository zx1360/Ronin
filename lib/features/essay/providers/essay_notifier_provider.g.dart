// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'essay_notifier_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$browseManagerHash() => r'82b7f6aa5d645499e278c563ff86ffa7866d20ca';

/// See also [BrowseManager].
@ProviderFor(BrowseManager)
final browseManagerProvider =
    AutoDisposeNotifierProvider<BrowseManager, BrowseSettings>.internal(
  BrowseManager.new,
  name: r'browseManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$browseManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$BrowseManager = AutoDisposeNotifier<BrowseSettings>;
String _$contentServerHash() => r'34eb93eacce6caf6c301cafe81b79f2c7f5df5d5';

/// See also [ContentServer].
@ProviderFor(ContentServer)
final contentServerProvider =
    AutoDisposeNotifierProvider<ContentServer, Essay?>.internal(
  ContentServer.new,
  name: r'contentServerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$contentServerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ContentServer = AutoDisposeNotifier<Essay?>;
String _$essayServiceHash() => r'70a503ae8b66ce8057fcada805f76c06604e5094';

/// See also [EssayService].
@ProviderFor(EssayService)
final essayServiceProvider =
    AutoDisposeNotifierProvider<EssayService, Cashier>.internal(
  EssayService.new,
  name: r'essayServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$essayServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$EssayService = AutoDisposeNotifier<Cashier>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
