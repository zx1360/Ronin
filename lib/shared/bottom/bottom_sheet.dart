import 'package:flutter/material.dart';

void openBottomSheet(
  BuildContext context, {
  required String initialListId,
  required Widget widget,
  required double heightPercentage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * heightPercentage,
      ),
      child: widget,
    ),
  );
}
