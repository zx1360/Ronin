import 'package:flutter/widgets.dart';

class NewTask {
  final int index;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  String imagePath;

  NewTask({
    required this.index,
    required this.titleCtrl,
    required this.descCtrl,
    this.imagePath = "",
  });
}
