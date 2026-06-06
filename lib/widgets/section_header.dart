import 'package:flutter/material.dart';

/// Reusable section header with emoji + title + optional action button.
///
/// Visual contract:
/// - Renders emoji at fontSize 24 followed by title in `titleLarge` style.
/// - When [onAction] is non-null, renders a trailing [IconButton] (default
///   icon is [Icons.add]; pass [actionIcon] to override).
class SectionHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const SectionHeader({
    super.key,
    required this.emoji,
    required this.title,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (onAction != null)
          IconButton(
            icon: Icon(actionIcon ?? Icons.add),
            onPressed: onAction,
          ),
      ],
    );
  }
}
