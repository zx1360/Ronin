import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  final AsyncValue<T> asyncValue;
  final Widget Function(T data) dataBuilder;
  const AsyncValueWidget({super.key, required this.asyncValue, required this.dataBuilder});

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      data: (data) => dataBuilder(data),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('出错咯: $error')),
    );
  }
}