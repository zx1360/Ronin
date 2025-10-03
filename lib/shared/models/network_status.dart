import 'package:dio/dio.dart';

class NetworkStatus {
  final CancelToken cancelToken;
  final ProgressCallback progressCallback;

  NetworkStatus({required this.cancelToken, required this.progressCallback});
}