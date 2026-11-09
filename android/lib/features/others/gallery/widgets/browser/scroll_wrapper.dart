part of '../../pages/medias_browser_page.dart';

class _DraggableScrollWrapper extends StatelessWidget {
  final Widget child;
  final ScrollController scrollController;

  const _DraggableScrollWrapper({
    required this.child,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) => RawScrollbar(
    controller: scrollController,
    thumbVisibility: true,
    trackVisibility: true,
    interactive: true,
    thickness: _kScrollbarTrackWidth,
    radius: const Radius.circular(4),
    thumbColor: Colors.white54,
    trackColor: Colors.white10,
    trackBorderColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.only(right: _kScrollbarTrackWidth + 4),
      child: child,
    ),
  );
}
