import 'package:dio/dio.dart';
import 'package:torrid/core/services/network/api_client.dart';
import 'package:torrid/features/essay/models/essay.dart';

typedef EssaySuggestions = ({
  String title,
  List<String> labels,
  List<String> removeLabels,
  String reason,
});

Future<EssaySuggestions> suggestEssay({
  required ApiClient api,
  required String model,
  required Essay essay,
  required Map<String, String> labelPaths,
  required CancelToken cancelToken,
  String? branch,
}) async {
  final response = await api.postJson(
    '/API/ai/essay/suggestions',
    cancelToken: cancelToken,
    receiveTimeout: const Duration(minutes: 5),
    data: {
      'model': model,
      'title': essay.title,
      'content': essay.content,
      'current_labels': essay.labels,
      'candidates': [
        for (final entry in labelPaths.entries)
          {'id': entry.key, 'path': entry.value},
      ],
      if (branch != null) 'branch': branch,
    },
  );
  final json = response.data as Map<String, dynamic>;
  return (
    title: json['title'] as String,
    labels: (json['labels'] as List).cast<String>(),
    removeLabels: (json['remove_labels'] as List).cast<String>(),
    reason: json['reason'] as String,
  );
}
