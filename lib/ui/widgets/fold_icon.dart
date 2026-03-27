import 'package:flutter/material.dart';

import '../theme.dart';

/// Animated expand/collapse chevron icon with rotation transition.
class FoldIcon extends StatelessWidget {
  final bool isFolded;
  final bool visible;
  final VoidCallback? onTap;

  const FoldIcon({
    super.key,
    required this.isFolded,
    required this.visible,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox(width: 20, height: 20);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 20,
        height: 20,
        child: Center(
          child: AnimatedRotation(
            turns: isFolded ? 0.0 : 0.25,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
