import 'package:flutter/material.dart';

import '../theme.dart';

/// Custom-painted bullet icon for outliner nodes.
/// Shows a filled circle for nodes with no children,
/// and a slightly larger circle for nodes with children.
class BulletIcon extends StatelessWidget {
  final bool hasChildren;
  final bool isCompleted;

  const BulletIcon({
    super.key,
    required this.hasChildren,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: hasChildren ? 7 : 5,
          height: hasChildren ? 7 : 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppTheme.textMuted
                : hasChildren
                    ? AppTheme.accentPrimary
                    : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
