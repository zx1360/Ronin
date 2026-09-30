part of '../../pages/medias_browser_page.dart';

/// 底部操作栏按钮
class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const _BottomButton({
    required this.icon,
    required this.label,
    this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color ?? Colors.white),
      label: Text(
        label,
        style: TextStyle(color: color ?? Colors.white),
      ),
    );
  }
}
