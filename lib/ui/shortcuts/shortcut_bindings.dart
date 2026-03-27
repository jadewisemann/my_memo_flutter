import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'shortcut_intents.dart';

/// Map keyboard keys to outliner intents.
/// Uses Cmd on macOS, Ctrl on other platforms.
/// Note: Backspace for merging nodes is handled via onKeyEvent to allow native TextField text deletion passthrough.
Map<ShortcutActivator, Intent> get outlinerShortcuts {
  final bool isMac = defaultTargetPlatform == TargetPlatform.macOS;

  return {
    // Enter → Split node or Create sibling below
    const SingleActivator(LogicalKeyboardKey.enter): const SplitOrCreateNodeIntent(),

    // Ctrl/Cmd + Enter → Force create below immediately
    SingleActivator(LogicalKeyboardKey.enter, control: !isMac, meta: isMac): const ForceCreateNodeBelowIntent(),

    // Tab → Indent
    const SingleActivator(LogicalKeyboardKey.tab): const IndentNodeIntent(),

    // Shift+Tab → Outdent
    const SingleActivator(LogicalKeyboardKey.tab, shift: true): const OutdentNodeIntent(),

    // Alt/Option + Up → Move node subtree up
    const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): const MoveSubtreeUpIntent(),

    // Alt/Option + Down → Move node subtree down
    const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): const MoveSubtreeDownIntent(),

    // Ctrl/Cmd + . → Toggle fold
    SingleActivator(LogicalKeyboardKey.period, control: !isMac, meta: isMac): const ToggleFoldIntent(),

    // Ctrl/Cmd + Shift + K → Force Delete node (even if not empty)
    SingleActivator(LogicalKeyboardKey.keyK, control: !isMac, meta: isMac, shift: true): const ForceDeleteNodeIntent(),

    // Ctrl/Cmd + L → Toggle Node Selection
    SingleActivator(LogicalKeyboardKey.keyL, control: !isMac, meta: isMac): const ToggleNodeSelectionIntent(),

    // Shift + Up/Down → Instant Block Selection Expansion
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): const ExpandSelectionUpIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): const ExpandSelectionDownIntent(),
  };
}
