import 'package:flutter/material.dart';
import 'package:torrid/core/modals/snack_bar.dart';

const traceInk = Color(0xff24322b);
const traceForest = Color(0xff305746);
const tracePaper = Color(0xfff7f6f0);
const traceLine = Color(0xffdedfd4);
const tracePanel = Color(0xfffffffb);

ThemeData traceTheme(ThemeData base) {
  final colors = ColorScheme.fromSeed(seedColor: traceForest).copyWith(
    primary: traceForest,
    primaryContainer: const Color(0xffe3ebdf),
    onPrimaryContainer: traceInk,
    surface: tracePaper,
    surfaceContainer: tracePanel,
    onSurface: traceInk,
    onSurfaceVariant: const Color(0xff596258),
    outlineVariant: traceLine,
  );
  return base.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: tracePaper,
    canvasColor: tracePaper,
    textTheme: base.textTheme.apply(
      bodyColor: traceInk,
      displayColor: traceInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: tracePaper,
      foregroundColor: traceInk,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: traceInk,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: tracePanel),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
    ),
    textButtonTheme: const TextButtonThemeData(),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: tracePanel,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: traceLine),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}

MaterialPageRoute<T> traceRoute<T>(Widget page) => MaterialPageRoute<T>(
  builder: (context) => Theme(data: traceTheme(Theme.of(context)), child: page),
);

class TracePanel extends StatelessWidget {
  const TracePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = tracePanel,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: traceLine),
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

class TraceDot extends StatelessWidget {
  const TraceDot(this.color, {super.key, this.size = 9});

  final int color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: Color(color), shape: BoxShape.circle),
  );
}

String traceError(Object error) => switch (error) {
  StateError(:final message) => message,
  ArgumentError(:final message) => '$message',
  _ => '操作未完成，请重试。',
};

Future<void> traceAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) displaySnackBar(context, traceError(error));
  }
}

Future<bool> confirmTraceDiscard(
  BuildContext context,
  String title,
  String message, {
  String action = '丢弃',
  bool destructive = true,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: traceTheme(Theme.of(context)),
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              child: Text(action),
            ),
          ],
        ),
      ),
    ) ??
    false;
