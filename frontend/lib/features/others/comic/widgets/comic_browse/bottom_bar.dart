import 'package:flutter/material.dart';

class BottomControllBar extends StatelessWidget {
  final Function prevFunc;
  final Function nextFunc;
  final double slideVal;
  final Function(double) onSlideFunc;
  final VoidCallback onSlideStart;
  final VoidCallback onSlideEnd;
  const BottomControllBar({
    super.key,
    required this.prevFunc,
    required this.nextFunc,
    required this.slideVal,
    required this.onSlideFunc,
    required this.onSlideStart,
    required this.onSlideEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
          left: 12,
          right: 12,
          top: 16,
        ),
        color: Colors.black54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () {
                prevFunc();
              },
              disabledColor: Colors.grey,
            ),
            // 进度条
            if (slideVal == -1)
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Text('1/1', style: TextStyle(color: Colors.white)),
                ),
              ),
            if (slideVal != -1)
              Expanded(
                child: Slider(
                  value: slideVal,
                  onChanged: (value) {
                    onSlideFunc(value);
                  },
                  onChangeStart: (_)=>onSlideStart(),
                  onChangeEnd: (_)=>onSlideEnd(),
                  activeColor: Colors.white,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: () {
                nextFunc();
              },
              disabledColor: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
