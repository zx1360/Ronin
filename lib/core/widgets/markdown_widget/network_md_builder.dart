import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'md_viewer.dart';

/// 网络 Markdown 内容构建器
/// 从网络 URL 加载 Markdown 内容并渲染
class NetworkMdBuilder extends StatefulWidget {
  /// Markdown 文件的网络地址
  final String url;

  /// 请求超时时间（秒）
  final int timeoutSeconds;

  /// 自定义请求头
  final Map<String, String>? headers;

  /// 是否显示 AppBar
  final bool showAppBar;

  /// AppBar 标题
  final String? title;

  const NetworkMdBuilder({
    super.key,
    required this.url,
    this.timeoutSeconds = 30,
    this.headers,
    this.showAppBar = false,
    this.title,
  });

  @override
  State<NetworkMdBuilder> createState() => _NetworkMdBuilderState();
}

class _NetworkMdBuilderState extends State<NetworkMdBuilder> {
  /// 加载的 Markdown 内容
  String? _content;

  /// 加载状态
  bool _isLoading = true;

  /// 错误信息
  String? _errorMessage;

  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: widget.timeoutSeconds),
        receiveTimeout: Duration(seconds: widget.timeoutSeconds),
        headers: widget.headers,
      ),
    );
    _loadMarkdownFromNetwork();
  }

  @override
  void didUpdateWidget(covariant NetworkMdBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL 变化时重新加载
    if (oldWidget.url != widget.url) {
      _loadMarkdownFromNetwork();
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  /// 从网络加载 Markdown 内容
  Future<void> _loadMarkdownFromNetwork() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.get<String>(widget.url);

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _content = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = '请求失败：状态码 ${response.statusCode}';
        });
      }
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _formatDioError(e);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败：${e.toString()}';
      });
    }
  }

  /// 格式化 Dio 错误信息
  String _formatDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请稍后重试';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请稍后重试';
      case DioExceptionType.badResponse:
        return '服务器响应错误：${e.response?.statusCode}';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.connectionError:
        return '网络连接错误，请检查网络';
      default:
        return '网络请求失败：${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_isLoading) {
      body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载内容...'),
          ],
        ),
      );
    } else if (_errorMessage != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMarkdownFromNetwork,
                icon: const Icon(Icons.refresh),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = MdViewer(data: _content!);
    }

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? ''),
          actions: [
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadMarkdownFromNetwork,
                tooltip: '刷新',
              ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }
}
