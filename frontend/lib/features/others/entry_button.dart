import 'package:flutter/material.dart';

class PageItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  PageItem({
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class PageEntryButton extends StatelessWidget {
  final PageItem pageItem;

  const PageEntryButton({
    super.key,
    required this.pageItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: pageItem.builder),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pageItem.icon,
              size: 32,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              pageItem.label,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}