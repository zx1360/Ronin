class OpsSettings {
  final String apiBaseUrl;
  final String apiKey;
  final int autoRefreshSeconds;
  final bool hideApiKey;

  const OpsSettings({
    required this.apiBaseUrl,
    required this.apiKey,
    required this.autoRefreshSeconds,
    required this.hideApiKey,
  });

  factory OpsSettings.defaults() {
    return const OpsSettings(
      apiBaseUrl: 'http://127.0.0.1:7275',
      apiKey: '',
      autoRefreshSeconds: 10,
      hideApiKey: true,
    );
  }

  OpsSettings copyWith({
    String? apiBaseUrl,
    String? apiKey,
    int? autoRefreshSeconds,
    bool? hideApiKey,
  }) {
    return OpsSettings(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      apiKey: apiKey ?? this.apiKey,
      autoRefreshSeconds: autoRefreshSeconds ?? this.autoRefreshSeconds,
      hideApiKey: hideApiKey ?? this.hideApiKey,
    );
  }

  factory OpsSettings.fromJson(Map<String, dynamic> json) {
    return OpsSettings(
      apiBaseUrl: (json['apiBaseUrl'] ?? 'http://127.0.0.1:7275').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      autoRefreshSeconds: int.tryParse(
            (json['autoRefreshSeconds'] ?? '10').toString(),
          ) ??
          10,
      hideApiKey: json['hideApiKey'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiBaseUrl': apiBaseUrl,
      'apiKey': apiKey,
      'autoRefreshSeconds': autoRefreshSeconds,
      'hideApiKey': hideApiKey,
    };
  }
}
