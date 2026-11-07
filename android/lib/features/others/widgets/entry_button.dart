import 'package:flutter/material.dart';

class PageItem {
  final String label;
  final IconData icon;
  final String description;
  final WidgetBuilder builder;

  PageItem({
    required this.label,
    required this.icon,
    required this.description,
    required this.builder,
  });
}

class PageEntryButton extends StatelessWidget {
  final PageItem pageItem;

  const PageEntryButton({super.key, required this.pageItem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: pageItem.builder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(pageItem.icon, size: 32, color: theme.primaryColor),
              const SizedBox(height: 8),
              Text(pageItem.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                pageItem.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
