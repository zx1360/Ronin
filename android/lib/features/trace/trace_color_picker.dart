import 'package:flutter/material.dart';

import 'trace_scene.dart';
import 'trace_ui.dart';

Future<String?> pickTraceColor(BuildContext context, String initial) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TraceColorPicker(initial: initial),
    );

class _TraceColorPicker extends StatefulWidget {
  const _TraceColorPicker({required this.initial});

  final String initial;

  @override
  State<_TraceColorPicker> createState() => _TraceColorPickerState();
}

class _TraceColorPickerState extends State<_TraceColorPicker> {
  late final _hex = TextEditingController(text: widget.initial);
  late HSVColor _color = HSVColor.fromColor(traceSceneColor(widget.initial));

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _pick(HSVColor color) => setState(() {
    _color = color;
    _hex.text = traceColorFromRgb(color.toColor().toARGB32());
  });

  @override
  Widget build(BuildContext context) {
    final validHex = traceColorHex(_hex.text);
    final hue = _color.withSaturation(1).withValue(1).toColor();
    return AlertDialog(
      title: const Text('场景颜色'),
      scrollable: true,
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 136,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  void select(Offset point) => _pick(
                    _color
                        .withSaturation(
                          (point.dx / bounds.maxWidth).clamp(0.0, 1.0),
                        )
                        .withValue(
                          1 - (point.dy / bounds.maxHeight).clamp(0.0, 1.0),
                        ),
                  );
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) => select(details.localPosition),
                      onPanUpdate: (details) => select(details.localPosition),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.white, hue],
                              ),
                            ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                          ),
                          Positioned(
                            left: _color.saturation * (bounds.maxWidth - 16),
                            top: (1 - _color.value) * (bounds.maxHeight - 16),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _color.toColor(),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: '色相',
              child: Slider(
                value: _color.hue,
                max: 360,
                activeColor: hue,
                onChanged: (hue) =>
                    _pick(_color.withHue(hue == 360 ? 359.99 : hue)),
              ),
            ),
            TextField(
              controller: _hex,
              maxLength: 7,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '颜色值',
                hintText: '#RRGGBB',
                counterText: '',
                errorText: validHex == null ? '请输入六位十六进制颜色' : null,
                prefixIcon: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: TraceDot(_color.toColor(), size: 21),
                ),
              ),
              onChanged: (value) => setState(() {
                final color = traceColorHex(value);
                if (color != null) {
                  _color = HSVColor.fromColor(traceSceneColor(color));
                }
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: validHex == null
              ? null
              : () => Navigator.pop(context, validHex),
          child: const Text('使用此颜色'),
        ),
      ],
    );
  }
}
