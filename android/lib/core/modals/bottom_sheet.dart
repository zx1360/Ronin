import 'package:flutter/material.dart';
import 'package:torrid/core/constants/app_border_radius.dart';

void openBottomSheet(
  BuildContext context, {
  required Widget widget,
  required double heightPercentage,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppBorderRadius.xl)),
    ),
    builder: (context) => Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * heightPercentage,
      ),
      child: widget,
    ),
  );
}
