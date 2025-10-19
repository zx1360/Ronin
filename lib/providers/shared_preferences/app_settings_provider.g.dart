// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppSettings _$AppSettingsFromJson(Map<String, dynamic> json) => AppSettings(
      ip: json['ip'] as String,
      port: json['port'] as String,
      motto: json['motto'] as String,
      bgImgRelativePaths: (json['bgImgRelativePaths'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AppSettingsToJson(AppSettings instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'port': instance.port,
      'motto': instance.motto,
      'bgImgRelativePaths': instance.bgImgRelativePaths,
    };

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appSettingsProviderHash() =>
    r'81bf362288db2cabb60af1b16a7b5ca32b48754c';

/// See also [AppSettingsProvider].
@ProviderFor(AppSettingsProvider)
final appSettingsProviderProvider =
    AutoDisposeNotifierProvider<AppSettingsProvider, AppSettings>.internal(
  AppSettingsProvider.new,
  name: r'appSettingsProviderProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appSettingsProviderHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppSettingsProvider = AutoDisposeNotifier<AppSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
